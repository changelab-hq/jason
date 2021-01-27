class Jason::Subscription
  attr_accessor :id, :config

  def initialize(id: nil, config: nil)
    if id
      @id = id
      raw_config = $redis_jason.hgetall("jason:subscriptions:#{id}").map { |k,v| [k, JSON.parse(v)] }.to_h
      set_config(raw_config)
    else
      @id = Digest::MD5.hexdigest(config.sort_by { |key| key }.to_h.to_json)
      pp config.sort_by { |key| key }.to_h.to_json
      configure(config)
    end
    pp @id
  end

  def self.upsert_by_config(model, conditions: {}, includes: {})
    self.new(config: {
      model: model,
      conditions: conditions || {},
      includes: includes || {}
    })
  end

  def self.find_by_id(id)
    self.new(id: id)
  end

  def self.for_instance(model_name, id, include_all = true)
    subs = $redis_jason.smembers("jason:models:#{model_name}:#{id}:subscriptions")
    if include_all
      subs += $redis_jason.smembers("jason:models:#{model_name}:all:subscriptions")
    end

    subs
  end

  def self.for_model(model_name)

  end

  # Find and update subscriptions affected by a model changing foreign key
  # comment, comment_id, post, old_post_id, new_post_id
  def self.update_ids(model_name, id, parent_model_name, old_foreign_id, new_foreign_id)
    # Check if this change means it needs to be removed
    # First find subscriptions that reference this model

    if old_foreign_id
      old_model_subscriptions = for_instance(parent_model_name, old_foreign_id, false)
      new_model_subscriptions = for_instance(parent_model_name, new_foreign_id, false)
    else
      # If this is a new instance, we need to include _all_ subscriptions
      old_model_subscriptions = []
      new_model_subscriptions = for_instance(parent_model_name, new_foreign_id, true)
    end

    # To add
    (new_model_subscriptions - old_model_subscriptions).each do |sub_id|
      # add the current ID to the subscription, then add the tree below it
      find_by_id(sub_id).set_id(model_name, id)
    end

    # To remove
    (old_model_subscriptions - new_model_subscriptions).each do |sub_id|
      find_by_id(sub_id).remove_ids(model_name, [id])
    end

    # TODO changes to sub models - e.g. post -> comment -> user
  end

  def self.remove_ids(model_name, ids)
    ids.each do |instance_id|
      for_instance(model_name, instance_id, false).each do |sub_id|
        find_by_id(sub_id).remove_ids(model_name, [instance_id])
      end
    end
  end

  # Add ID to any _all_ subscriptions
  def self.add_id(model_name, id)

  end

  def self.all
    $redis_jason.keys('jason:subscriptions:*')
  end

  def set_config(raw_config)
    @config =  raw_config.with_indifferent_access
  end

  # E.g. add comment#123, and then sub models
  def set_id(model_name, id)
    commit_ids(model_name, [id])
    assoc_name = get_assoc_name(model_name)
    set_ids_for_sub_models(assoc_name, [id])
  end

  def clear_id(model_name, id, parent_model_name)
    remove_ids(model_name, [id])
  end

  # Set the instance IDs for the subscription
  # Add an entry to the subscription list for each instance
  def set_ids(assoc_name = model, referrer_model_name = nil, referrer_ids = nil, enforce: false)
    model_name = assoc_name.to_s.singularize

    if referrer_model_name.blank? && conditions.blank?
      $redis_jason.sadd("jason:models:#{model_name}:all:subscriptions", id)
      ids = model_klass(model_name).all.pluck(:id)
      set_ids_for_sub_models(assoc_name, ids, enforce: enforce)
      return
    end

    if referrer_model_name.blank?
      ids = model_klass(model_name).where(conditions).pluck(:id)
    else
      assoc = model_klass(referrer_model_name).reflect_on_association(assoc_name.to_sym)

      if assoc.is_a?(ActiveRecord::Reflection::HasManyReflection)
        ids = model_klass(model_name).where(assoc.foreign_key => referrer_ids).pluck(:id)
      elsif assoc.is_a?(ActiveRecord::Reflection::BelongsToReflection)
        ids = model_klass(referrer_model_name).where(id: referrer_ids).pluck(assoc.foreign_key)
      end
    end
    return if ids.blank?

    enforce ? enforce_ids(model_name, ids) : commit_ids(model_name, ids)
    set_ids_for_sub_models(assoc_name, ids, enforce: enforce)
  end

  def refresh_ids(assoc_name = model, referrer_model_name = nil, referrer_ids)

  end

  # Add IDs that aren't present
  def commit_ids(model_name, ids)
    pp 'COMMIT'
    pp model_name
    pp ids
    $redis_jason.sadd("jason:subscriptions:#{id}:ids:#{model_name}", ids)
    ids.each do |instance_id|
      $redis_jason.sadd("jason:models:#{model_name}:#{instance_id}:subscriptions", id)
    end
  end

  # Ensure IDs are _only_ the ones passed
  def enforce_ids(model_name, ids)
    old_ids = $redis_jason.smembers("jason:subscriptions:#{id}:ids:#{model_name}")

    # Remove
    $redis_jason.srem("jason:subscriptions:#{id}:ids:#{model_name}", (old_ids - ids))

    (old_ids - ids).each do |instance_id|
      $redis_jason.srem("jason:models:#{model_name}:#{instance_id}:subscriptions", id)
    end

    # Add
    $redis_jason.sadd("jason:subscriptions:#{id}:ids:#{model_name}", (ids - old_ids))

    (ids - old_ids).each do |instance_id|
      $redis_jason.sadd("jason:models:#{model_name}:#{instance_id}:subscriptions", id)
    end
  end

  def remove_ids(model_name, ids)
    $redis_jason.srem("jason:subscriptions:#{id}:ids:#{model_name}", ids)
    ids.each do |instance_id|
      $redis_jason.srem("jason:models:#{model_name}:#{instance_id}:subscriptions", id)
    end
  end

  # 'posts', [post#1, post#2,...]
  def set_ids_for_sub_models(assoc_name, ids, enforce: false)
    model_name = assoc_name.to_s.singularize
    # Limitation: Same association can't appear twice
    includes_tree = get_tree_for(assoc_name)

    if includes_tree.is_a?(Hash)
      includes_tree.each do |assoc_name, includes_tree|
        set_ids(assoc_name, model_name, ids, enforce: enforce)
      end
    # [:likes, :user]
    elsif includes_tree.is_a?(Array)
      includes_tree.each do |assoc_name|
        set_ids(assoc_name, model_name, ids, enforce: enforce)
      end
    elsif includes_tree.is_a?(String)
      set_ids(includes_tree, model_name, ids, enforce: enforce)
    end
  end

  # assoc could be plural or not, so need to scan both.
  def get_assoc_name(model_name, haystack = includes)
    return model_name if model_name == model

    if haystack.is_a?(Hash)
      haystack.each do |assoc_name, includes_tree|
        if model_name.pluralize == assoc_name.to_s.pluralize
          return assoc_name
        else
          found_assoc = get_assoc_name(model_name, includes_tree)
          return found_assoc if found_assoc
        end
      end
    elsif haystack.is_a?(Array)
      haystack.each do |assoc_name|
        if model_name.pluralize == assoc_name.to_s.pluralize
          return assoc_name
        end
      end
    else
      if model_name.pluralize == haystack.to_s.pluralize
        return haystack
      end
    end

    return nil
  end

  def get_tree_for(needle, assoc_name = nil, haystack = includes)
    return includes if needle == model
    return haystack if needle.to_s == assoc_name.to_s

    if haystack.is_a?(Hash)
      haystack.each do |assoc_name, includes_tree|
        found_haystack = get_tree_for(needle, assoc_name, includes_tree)
        return found_haystack if found_haystack
      end
    end

    return nil
  end

  def all_models(tree = includes)
    sub_models = if tree.is_a?(Hash)
      tree.map do |k,v|
        [k, all_models(v)]
      end
    else
      tree
    end

    pp ([model] + [sub_models]).flatten.uniq.map(&:to_s).map(&:singularize)
    ([model] + [sub_models]).flatten.uniq.map(&:to_s).map(&:singularize)
  end

  def clear_all_ids(assoc_name = model)
    model_name = assoc_name.to_s.singularize
    includes_tree = model_name == model ? includes : get_tree_for(assoc_name)

    if model_name == model && conditions.blank?
      $redis_jason.srem("jason:models:#{model_name}:all:subscriptions", id)
    end

    ids = $redis_jason.smembers("jason:subscriptions:#{id}:ids:#{model_name}")
    ids.each do |instance_id|
      $redis_jason.srem("jason:models:#{model_name}:#{instance_id}:subscriptions", id)
    end
    $redis_jason.del("jason:subscriptions:#{id}:ids:#{model_name}")

    # Recursively clear IDs
    # { comments: [:like] }
    if includes_tree.is_a?(Hash)
      includes_tree.each do |assoc_name, includes_tree|
        clear_all_ids(assoc_name)
      end
    # [:likes, :user]
    elsif includes_tree.is_a?(Array)
      includes_tree.each do |assoc_name|
        clear_all_ids(assoc_name)
      end
    elsif includes_tree.is_a?(String)
      clear_all_ids(includes_tree)
    end
  end

  def ids(model_name = model)
    $redis_jason.smembers("jason:subscriptions:#{id}:ids:#{model_name}")
  end

  def model
    @config['model']
  end

  def model_klass(model_name)
    model_name.to_s.classify.constantize
  end

  def conditions
    @config['conditions']
  end

  def includes
    @config['includes']
  end

  def configure(raw_config)
    set_config(raw_config)
    $redis_jason.hmset("jason:subscriptions:#{id}", *config.map { |k,v| [k, v.to_json] }.flatten)
  end

  def destroy
    raise
  end

  def add_consumer(consumer_id)
    before_consumer_count = consumer_count
    $redis_jason.sadd("jason:subscriptions:#{id}:consumers", consumer_id)
    $redis_jason.hset("jason:consumers", consumer_id, Time.now.utc)

    if before_consumer_count == 0
      set_ids
    end
  end

  def remove_consumer(consumer_id)
    $redis_jason.srem("jason:subscriptions:#{id}:consumers", consumer_id)
    $redis_jason.hdel("jason:consumers", consumer_id)

    if consumer_count == 0
      clear_all_ids
    end
  end

  def consumer_count
    $redis_jason.scard("jason:subscriptions:#{id}:consumers")
  end

  def channel
    "jason:#{id}"
  end

  def get
    all_models.map { |model_name| get_for_model(model_name) }
  end

  def get_for_model(model_name)
    if $redis_jason.sismember("jason:models:#{model_name}:all:subscriptions", id)
      instance_jsons_hash, idx = $redis_jason.multi do |r|
        r.hgetall("jason:cache:#{model_name}")
        r.get("jason:subscription:#{id}:#{model_name}:idx")
      end
      instance_jsons = instance_jsons_hash.values
    else
      instance_jsons, idx = Jason::LuaGenerator.new.get_payload(model_name, id)
    end

    return if instance_jsons.blank?

    payload = instance_jsons.map do |instance_json|
      instance_json ? JSON.parse(instance_json) : {}
    end

    {
      type: 'payload',
      model: model_name,
      payload: payload,
      md5Hash: id,
      idx: idx.to_i
    }
  end

  def update(model_name, instance_id, payload, gidx)
    idx = Jason::LuaGenerator.new.get_subscription(model_name, instance_id, id, gidx)
    return if idx.blank?

    payload = {
      id: instance_id,
      model: model_name,
      payload: payload,
      md5Hash: id,
      idx: idx.to_i
    }

    ActionCable.server.broadcast(channel, payload)
  end

  def destroy(model_name, instance_id)
    idx = $redis_jason.incr("jason:subscription:#{id}:#{model_name}idx")

    payload = {
      id: instance_id,
      model: model_name,
      destroy: true,
      md5Hash: id,
      idx: idx.to_i
    }

    ActionCable.server.broadcast(channel, payload)
  end
end
