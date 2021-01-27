class Jason::LuaGenerator
  ## TODO load these scripts and evalsha
  def cache_json(model_name, id, payload)
    cmd = <<~LUA
      local gidx = redis.call('INCR', 'jason:gidx')
      redis.call( 'set', 'jason:cache:' .. ARGV[1] .. ':' .. ARGV[2] .. ':gidx', gidx )
      redis.call( 'hset', 'jason:cache:' .. ARGV[1], ARGV[2], ARGV[3] )
      return gidx
    LUA

    result = $redis_jason.eval cmd, [], [model_name, id, payload.to_json]
  end

  def get_payload(model_name, sub_id)
    # If value has changed, return old value and new idx. Otherwise do nothing.
    cmd = <<~LUA
      local t = {}
      local models = {}
      local ids = redis.call('smembers', 'jason:subscriptions:' .. ARGV[2] .. ':ids:' .. ARGV[1])

      for k,id in pairs(ids) do
        models[#models+1] = redis.call( 'hget', 'jason:cache:' .. ARGV[1], id)
      end

      t[#t+1] = models
      t[#t+1] = redis.call( 'get', 'jason:subscription:' .. ARGV[2] .. ':' .. ARGV[1] .. ':idx' )

      return t
    LUA

    $redis_jason.eval cmd, [], [model_name, sub_id]
  end

  def get_subscription(model_name, id, sub_id, gidx)
    # If value has changed, return old value and new idx. Otherwise do nothing.
    cmd = <<~LUA
      local last_gidx = redis.call('get', 'jason:cache:' .. ARGV[1] .. ':' .. ARGV[2] .. ':gidx') or 0

      if (ARGV[4] >= last_gidx) then
        local sub_idx = redis.call( 'incr', 'jason:subscription:' .. ARGV[3] .. ':' .. ARGV[1] .. ':idx' )
        return sub_idx
      else
        return false
      end
    LUA

    result = $redis_jason.eval cmd, [], [model_name, id, sub_id, gidx]
  end
end