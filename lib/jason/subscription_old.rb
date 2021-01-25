class Jason::SubscriptionOld
  attr_accessor :id, :config

  def initialize(id: nil, config: nil)
    if id
      @id = id
      raw_config = $redis_jason.hgetall("jason:subscriptions:#{id}").map { |k,v| [k, JSON.parse(v)] }.to_h
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
    $redis_jason.hmset("jason:subscriptions:#{id}", *config.map { |k,v| [k, v.to_json]}.flatten)
  end

  def destroy
    config.each do |model, value|
      $redis_jason.srem("jason:#{model.to_s.underscore}:subscriptions", id)
    end
    $redis_jason.del("jason:subscriptions:#{id}")
  end

  def add_consumer(consumer_id)
    before_consumer_count = consumer_count
    $redis_jason.sadd("jason:subscriptions:#{id}:consumers", consumer_id)
    $redis_jason.hset("jason:consumers", consumer_id, Time.now.utc)

    add_subscriptions
    publish_all
  end

  def remove_consumer(consumer_id)
    $redis_jason.srem("jason:subscriptions:#{id}:consumers", consumer_id)
    $redis_jason.hdel("jason:consumers", consumer_id)

    if consumer_count == 0
      remove_subscriptions
    end
  end

  def consumer_count
    $redis_jason.scard("jason:subscriptions:#{id}:consumers")
  end

  def channel
    "jason:#{id}"
  end

  def publish_all
    config.each do |model, model_config|
      klass = model.to_s.classify.constantize
      conditions = model_config['conditions'] || {}
      klass.where(conditions).find_each(&:cache_json)
      update(model)
    end
  end

  def add_subscriptions
    config.each do |model, value|
      $redis_jason.hset("jason:#{model.to_s.underscore}:subscriptions", id, value.to_json)
      update(model)
    end
  end

  def remove_subscriptions
    config.each do |model, _|
      $redis_jason.hdel("jason:#{model.to_s.underscore}:subscriptions", id)
    end
  end

  def self.publish_all
    JASON_API_MODEL.each do |model, _v|
      klass = model.to_s.classify.constantize
      klass.publish_all(klass.all) if klass.respond_to?(:publish_all)
    end
  end

  def get(model_name)
    LuaGenerator.new.index_hash_by_set("jason:cache:#{model_name}", "")

    value = JSON.parse($redis_jason.get("#{channel}:#{model}:value") || '[]')
    idx = $redis_jason.get("#{channel}:#{model}:idx").to_i

    {
      type: 'payload',
      md5Hash: id,
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
      $throttle_rate = ($redis_jason.get('global_throttle_rate') || 0).to_i
    else
      $throttle_rate
    end
  end

  # Atomically update and return patch
  def update(model)
    start_time = Time.now.utc
    conditions = config[model]['conditions']

    value = $redis_jason.hgetall("jason:#{model}:cache")
      .values.map { |v| JSON.parse(v) }
      .select { |v| (conditions || {}).all? { |field, value| v[field] == value } }
      .sort_by { |v| v['id'] }

    # lfsa = last finished, started at
    # If another job that started after this one, finished before this one, skip sending this state update
    if Time.parse($redis_jason.get("jason:#{channel}:lfsa") || '1970-01-01 00:00:00 UTC') < start_time
      $redis_jason.set("jason:#{channel}:lfsa", start_time)
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

    result = $redis_jason.eval cmd, [], ["#{channel}:#{model}", value.to_json]
    return if result.blank?

    idx = result[0]
    old_value = JSON.parse(result[1] || '[]')
    diff = get_diff(old_value, value)

    end_time = Time.now.utc

    payload = {
      model: model,
      md5Hash: id,
      diff: diff,
      idx: idx.to_i,
      latency: ((end_time - start_time)*1000).round
    }

    ActionCable.server.broadcast("jason:#{id}", payload)
  end
end
