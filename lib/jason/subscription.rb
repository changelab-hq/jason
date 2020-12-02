class Jason::Subscription
  attr_accessor :id, :config

  def initialize(id: nil, config: nil)
    if id
      @id = id
      raw_config = $redis.hgetall("jason:subscriptions:#{id}").map { |k,v| [k, JSON.parse(v)] }.to_h.with_indifferent_access
      set_config(raw_config)
    else
      @id = Digest::MD5.hexdigest(config.to_json)
      configure(config)
    end
  end

  def set_config(raw_config)
    @config =  raw_config.with_indifferent_access.map { |k,v| [k.underscore.to_s, v] }.to_h
  end

  def configure(raw_config)
    set_config(raw_config)
    $redis.hmset("jason:subscriptions:#{id}", *config.map { |k,v| [k, v.to_json]}.flatten)

    config.each do |model, value|
      puts model
      $redis.hset("jason:#{model.to_s.underscore}:subscriptions", id, value.to_json)
      update(model)
    end
  end

  def destroy
    config.each do |model, value|
      $redis.srem("jason:#{model.to_s.underscore}:subscriptions", id)
    end
    $redis.del("jason:subscriptions:#{id}")
  end

  def add_consumer(consumer_id)
    $redis.sadd("jason:subscriptions:#{id}:consumers", consumer_id)
  end

  def remove_consumer(consumer_id)
    $redis.srem("jason:subscriptions:#{id}:consumers", consumer_id)
  end

  def channel
    "jason:#{id}"
  end

  def self.publish_all
    JASON_API_MODEL.each do |model, _v|
      klass = model.to_s.classify.constantize
      klass.publish_all(klass.all) if klass.respond_to?(:publish_all)
    end
  end

  def get(model)
    value = JSON.parse($redis.get("#{channel}:#{model}:value") || '{}')
    idx = $redis.get("#{channel}:#{model}:idx").to_i

    {
      type: 'payload',
      model: model,
      value: value,
      idx: idx
    }
  end

  def get_diff(old_value, value)
    JsonDiff.generate(old_value, value)
  end

  def deep_stringify(value)
    if value.is_a?(Hash)
      value.deep_stringify_keys
    elsif value.is_a?(Array)
      value.map { |x| x.deep_stringify_keys }
    end
  end

  def get_throttle
    if !$throttle_rate || !$throttle_timeout || Time.now.utc > $throttle_timeout
      $throttle_timeout = Time.now.utc + 5.seconds
      $throttle_rate = (Sidekiq.redis { |r| r.get 'global_throttle_rate' } || 0).to_i
    else
      $throttle_rate
    end
  end

  # Atomically update and return patch
  def update(model)
    start_time = Time.now.utc
    conditions = config[model]['conditions']

    value = $redis.hgetall("jason:#{model}:cache")
      .values.map { |v| JSON.parse(v) }
      .select { |v| (conditions || {}).all? { |field, value| v[field] == value } }
      .sort_by { |v| v['id'] }

    # lfsa = last finished, started at
    # If another job that started after this one, finished before this one, skip sending this state update
    if Time.parse(Sidekiq.redis { |r| r.get("jason:#{channel}:lfsa") || '1970-01-01 00:00:00 UTC' } ) < start_time
      Sidekiq.redis { |r| r.set("jason:#{channel}:lfsa", start_time) }
    else
      return
    end

    value = deep_stringify(value)

    # If value has changed, return old value and new idx. Otherwise do nothing.
    cmd = <<~LUA
      local old_val=redis.call('get', ARGV[1] .. ':value')
      if old_val ~= ARGV[2] then
        redis.call('set', ARGV[1] .. ':value', ARGV[2])
        local new_idx = redis.call('incr', ARGV[1] .. ':idx')
        return { new_idx, old_val }
      end
    LUA

    result = $redis.eval cmd, [], ["#{channel}:#{model}", value.to_json]
    return if result.blank?

    idx = result[0]
    old_value = JSON.parse(result[1] || '{}')

    diff = get_diff(old_value, value)

    end_time = Time.now.utc

    payload = {
      model: model,
      diff: diff,
      idx: idx.to_i,
      latency: ((end_time - start_time)*1000).round
    }

    ActionCable.server.broadcast("jason:#{id}", payload)
  end
end
