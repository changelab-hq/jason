class Jason::Subscription
  attr_accessor :id, :config

  def initialize(id: nil, config: nil)
    if id
      @id = id
      @config = $redis.hgetall("jason:subscriptions:#{id}").map { |k,v| [k, JSON.parse(v)] }.to_h.with_indifferent_access
    else
      @id = Digest::MD5.hexdigest(config.to_json)
      configure(config)
    end
  end

  def configure(config)
    @config = config.with_indifferent_access
    $redis.hmset("jason:subscriptions:#{id}", *config.map { |k,v| [k, v.to_json]}.flatten)
    config.each do |model, value|
      $redis.hset("jason:#{model}:subscriptions", id, value.to_json)
      update(model)
    end
  end

  def destroy
    config.each do |model, value|
      $redis.srem("jason:#{model}:subscriptions", id)
    end
    $redis.del("jason:subscriptions:#{id}")
  end

  def channel
    "jason:#{id}"
  end

  def self.publish_all
    JASON_API_MODEL.each do |model, _v|
      klass = model.to_s.classify.constantize
      klass.publish_all if klass.respond_to?(:publish_all)
    end
  end

  include ::NewRelic::Agent::MethodTracer

  def get
    keys = config.keys.map do |model|
      ["#{channel}:#{model}:value", "#{channel}:#{model}:idx"]
    end.flatten

    result = $redis.mget(keys).each_slice(2).to_a.map do |x|
      value = JSON.parse(x[0] || '[]')
      idx = x[1].to_i
      { idx: idx, value: value }
    end

    models = config.keys.zip(result).to_h

    {
      type: 'payload',
      models: models
    }
  end
  add_method_tracer :get, 'JsonSub/get'

  def get_diff(old_value, value)
    JsonDiff.generate(old_value, value)
  end
  add_method_tracer :get_diff, 'JsonSub/get_diff'

  def deep_stringify(value)
    if value.is_a?(Hash)
      value.deep_stringify_keys
    elsif value.is_a?(Array)
      value.map { |x| x.deep_stringify_keys }
    end
  end
  add_method_tracer :deep_stringify, 'JsonSub/stringify'

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
      models: {
        model => {
          diff: diff,
          idx: idx.to_i
        }
      },
      latency: ((end_time - start_time)*1000).round
    }

    ActionCable.server.broadcast("jason:#{id}", payload)
  end
  add_method_tracer :update, 'JsonSub/update'
end
