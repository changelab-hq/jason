class Jason::LuaGenerator
  ## TODO load these scripts and evalsha
  def cache_json(model_name, id, payload)
    expiry = 7*24*60*60 + rand(6*60*60)

    # ensure the content expires first
    cmd = <<~LUA
      local gidx = redis.call('INCR', 'jason:gidx')
      redis.call( 'setex', 'jason:cache:' .. ARGV[1] .. ':' .. ARGV[2] .. ':gidx', #{expiry}, gidx )
      redis.call( 'setex', 'jason:cache:' .. ARGV[1] .. ':' .. ARGV[2], #{expiry - 60}, ARGV[3] )
      return gidx
    LUA

    result = $redis_jason.eval cmd, [], [model_name, id, payload.to_json]
  end

  def get_payload(model_name, sub_id)
    # If value has changed, return old value and new idx. Otherwise do nothing.
    cmd = <<~LUA
      local t = {}
      local insts = {}
      local miss_ids = {}
      local ids = redis.call('smembers', 'jason:subscriptions:' .. ARGV[2] .. ':ids:' .. ARGV[1])

      for k,id in pairs(ids) do
        local result = redis.call( 'get', 'jason:cache:' .. ARGV[1] .. ':' .. id)
        if (result == false) then
          miss_ids[#miss_ids+1] = id
        else
          insts[#insts+1] = result
        end
      end

      if next(miss_ids) == nil then
        t[#t+1] = insts
        t[#t+1] = redis.call( 'get', 'jason:subscription:' .. ARGV[2] .. ':' .. ARGV[1] .. ':idx' )
      else
        t[#t+1] = miss_ids
        t[#t+1] = 'missing'
      end

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

    $redis_jason.eval cmd, [], [model_name, id, sub_id, gidx]
  end

  def update_set_with_diff(key, add_members, remove_members)
    cmd = <<~LUA
      local old_members = redis.call('smembers', KEYS[1])
      local add_size = ARGV[1]

      for k, m in pairs({unpack(ARGV, 2, add_size + 1)}) do
        redis.call('sadd', KEYS[1], m)
      end

      for k, m in pairs({unpack(ARGV, add_size + 2, #ARGV)}) do
        redis.call('srem', KEYS[1], m)
      end

      return old_members
    LUA

    args = [add_members.size, add_members, remove_members].flatten

    old_members = $redis_jason.eval cmd, [key], args
    return [old_members, (old_members + add_members - remove_members).uniq]
  end
end