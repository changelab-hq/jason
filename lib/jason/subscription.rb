class Jason::Subscription
  attr_accessor :id, :config
  attr_reader :includes_helper

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
    @includes_helper = Jason::IncludesHelper.new(self.config['model'], self.config['includes'])
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
    to_add = new_model_subscriptions - old_model_subscriptions
    to_add.each do |sub_id|
      # add the current ID to the subscription, then add the tree below it
      find_by_id(sub_id).set_id(model_name, id)
    end

    # To remove
    to_remove = old_model_subscriptions - new_model_subscriptions
    to_remove.each do |sub_id|
      find_by_id(sub_id).set_ids_for_sub_models(enforce: true)
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
    $redis_jason.smembers('jason:subscriptions').map { |id| Jason::Subscription.find_by_id(id) }
  end

  def set_config(raw_config)
    @config =  raw_config.with_indifferent_access
  end

  # E.g. add comment#123, and then sub models
  def set_id(model_name, id)
    set_ids_for_sub_models(model_name, [id])
  end

  def clear_id(model_name, id, parent_model_name)
    remove_ids(model_name, [id])
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
    ids_to_remove = old_ids - ids
    if ids_to_remove.present?
      $redis_jason.srem("jason:subscriptions:#{id}:ids:#{model_name}", ids_to_remove)
    end

    ids_to_remove.each do |instance_id|
      $redis_jason.srem("jason:models:#{model_name}:#{instance_id}:subscriptions", id)
    end

    # Add
    ids_to_add = ids - old_ids
    if ids_to_add.present?
      $redis_jason.sadd("jason:subscriptions:#{id}:ids:#{model_name}", ids_to_add)
    end

    ids_to_add.each do |instance_id|
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
  def set_ids_for_sub_models(model_name = model, ids = nil, enforce: false)
    # Limitation: Same association can't appear twice
    includes_tree = includes_helper.get_tree_for(includes_helper.get_assoc_name(model_name))
    all_models = includes_helper.all_models(includes_tree).select { |x| x.present? }

    if model_name != model
      all_models = (all_models - [model] + [model_name]).uniq
    end

    relation = model_name.classify.constantize.all.eager_load(includes_tree)
    pp all_models
    pp model_name
    pp "INCLUDES TREE"
    pp includes_tree
    puts relation.to_sql

    if model_name == model
      if conditions.blank?
        $redis_jason.sadd("jason:models:#{model_name}:all:subscriptions", id)
        all_models -= [model_name]
      else
        relation = relation.where(conditions)
      end
    else
      raise "Must supply IDs for sub models" if ids.nil?
      return if ids.blank?
      relation = relation.where(id: ids)
    end

    pluck_args = all_models.map { |m| "#{m.pluralize}.id" }
    pp "PLUCK ARGS"
    pp pluck_args
    instance_ids = relation.pluck(*pluck_args)

    # pluck returns only a 1D array if only 1 arg passed
    if all_models.size == 1
      instance_ids = [instance_ids]
    end

    all_models.each_with_index do |model_name, i|
      ids = instance_ids.map { |row| row[i] }.uniq.compact
      if ids.present?
        if enforce
          enforce_ids(model_name, ids)
        else
          commit_ids(model_name, ids)
        end
      end
    end
  end

  def clear_all_ids
    includes_helper.all_models.each do |model_name|
      if model_name == model && conditions.blank?
        $redis_jason.srem("jason:models:#{model_name}:all:subscriptions", id)
      end

      ids = $redis_jason.smembers("jason:subscriptions:#{id}:ids:#{model_name}")
      ids.each do |instance_id|
        $redis_jason.srem("jason:models:#{model_name}:#{instance_id}:subscriptions", id)
      end
      $redis_jason.del("jason:subscriptions:#{id}:ids:#{model_name}")
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

  def configure(raw_config)
    set_config(raw_config)
    $redis_jason.sadd("jason:subscriptions", id)
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
      set_ids_for_sub_models
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
    includes_helper.all_models.map { |model_name| get_for_model(model_name) }.compact
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
