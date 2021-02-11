class Jason::Subscription
  attr_accessor :id, :config
  attr_reader :includes_helper, :graph_helper

  def initialize(id: nil, config: nil)
    if id
      @id = id
      raw_config = $redis_jason.hgetall("jason:subscriptions:#{id}").map { |k,v| [k, JSON.parse(v)] }.to_h
      set_config(raw_config)
    else
      @id = Digest::MD5.hexdigest(config.sort_by { |key| key }.to_h.to_json)
      configure(config)
    end
    @includes_helper = Jason::IncludesHelper.new({ model => self.config['includes'] })
    @graph_helper = Jason::GraphHelper.new(self.id, @includes_helper)

    check_for_missing_keys
  end

  def check_for_missing_keys
    missing_keys = includes_helper.all_models - Jason.schema.keys.map(&:to_s)
    if missing_keys.present?
      raise "#{missing_keys.inspect} are not in the schema. Only models in the Jason schema can be subscribed."
    end
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

  def self.for_instance_with_child(model_name, id, child_model_name, include_all = true)
    sub_ids = for_instance(model_name, id, include_all = true)
    sub_ids.select do |sub_id|
      find_by_id(sub_id).includes_helper.in_sub(model_name, child_model_name)
    end
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
  def self.update_ids(changed_model_name, changed_model_id, foreign_model_name, old_foreign_id, new_foreign_id)
    # There are 4 cases to consider.
    # changed_instance ---/--- foreign_instance
    #                  \--+--- new_foreign_instance
    #
    # foreign instance can either be parent or child for a given subscription
    # 1. Child swap/add: foreign is child
    # 2. Stay in the family: foreign is parent + both old and new foreign instances are part of the sub
    # 3. Join the family: foreign is parent + only new foreign instance are part of the sub
    # 4. Leave the family: foreign is parent + only the old foreign instance is part of the sub

    #########
    # Subs where changed is parent
    sub_ids = for_instance_with_child(changed_model_name, changed_model_id, foreign_model_name, true)
    sub_ids.each do |sub_id|
      subscription = find_by_id(sub_id)
      id_changeset = subscription.graph_helper.apply_update({
        remove: [{
          model_names: [changed_model_name, foreign_model_name],
          instance_ids: [[changed_model_id, old_foreign_id]]
        }],
        add: [
          {
            model_names: [changed_model_name, foreign_model_name],
            instance_ids: [[changed_model_id, new_foreign_id]]
          },
          # Add IDs of child models
          subscription.load_ids_for_sub_models(foreign_model_name, new_foreign_id)
        ]
      })

      subscription.apply_id_changeset(id_changeset)
      subscription.broadcast_id_changeset(id_changeset)
    end

    old_sub_ids = for_instance_with_child(foreign_model_name, old_foreign_id, changed_model_name, true)
    new_sub_ids = for_instance_with_child(foreign_model_name, new_foreign_id, changed_model_name, true)

    #########
    # Subs where changed is child
    # + parent in both old + new
    # this is simple, only the edges need to change - no IDs can be changed
    (old_sub_ids & new_sub_ids).each do |sub_id|
      subscription = find_by_id(sub_id)
      subscription.graph_helper.apply_update({
        remove: [{
          model_names: [changed_model_name, foreign_model_name],
          instance_ids: [[changed_model_id, old_foreign_id]]
        }],
        add: [{
          model_names: [changed_model_name, foreign_model_name],
          instance_ids: [[changed_model_id, new_foreign_id]]
        }]
      })
    end

    #########
    # Subs where changed is child
    # + old parent wasn't in the sub, but new parent is
    # IE the changed instance is joining the sub
    # No edges are removed, just added
    (new_sub_ids - old_sub_ids).each do |sub_id|
      subscription = find_by_id(sub_id)
      id_changeset = subscription.graph_helper.apply_update({
        add: [
          {
            model_names: [changed_model_name, foreign_model_name],
            instance_ids: [[changed_model_id, new_foreign_id]]
          },
          # Add IDs of child models
          subscription.load_ids_for_sub_models(changed_model_name, changed_model_id)
        ]
      })

      subscription.apply_id_changeset(id_changeset)
      subscription.broadcast_id_changeset(id_changeset)
    end

    #########
    # Subs where changed is child
    # + old parent was in the sub, but new parent isn't
    # Just need to remove the link, orphan detection will do the rest
    (old_sub_ids - new_sub_ids).each do |sub_id|
      subscription = find_by_id(sub_id)
      id_changeset = subscription.graph_helper.apply_update({
        remove: [
          {
            model_names: [changed_model_name, foreign_model_name],
            instance_ids: [[changed_model_id, old_foreign_id]]
          }
        ]
      })

      subscription.apply_id_changeset(id_changeset)
      subscription.broadcast_id_changeset(id_changeset)
    end
  end

  def self.remove_ids(model_name, ids)
    # td: finish this
    ids.each do |instance_id|
      for_instance(model_name, instance_id, false).each do |sub_id|
        subscription = find_by_id(sub_id)

        subscription.graph_helper.apply_update({
          remove: [
            {
              model_names: [changed_model_name, foreign_model_name],
              instance_ids: [[changed_model_id, old_foreign_id]]
            }
          ]
        })

        subscription.apply_id_changeset(id_changeset)
        subscription.broadcast_id_changeset(id_changeset)
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
    @config =  raw_config.deep_stringify_keys.deep_transform_values { |v| v.is_a?(Symbol) ? v.to_s : v }
  end

  def clear_id(model_name, id, parent_model_name)
    remove_ids(model_name, [id])
  end

  def refresh_ids(assoc_name = model, referrer_model_name = nil, referrer_ids)

  end

  # Add IDs that aren't present
  def commit_ids(model_name, ids)
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

  def apply_id_changeset(changeset)
    changeset[:ids_to_add].each do |model_name, ids|
      commit_ids(model_name, ids)
    end

    changeset[:ids_to_remove].each do |model_name, ids|
      remove_ids(model_name, ids)
    end
  end

  def broadcast_id_changeset(changeset)
    changeset[:ids_to_add].each do |model_name, ids|
      ids.each { |id| add(model_name, id) }
    end

    changeset[:ids_to_remove].each do |model_name, ids|
      ids.each { |id| destroy(model_name, id) }
    end
  end

  # Take a model name and IDs and return an edge set of all the models that appear and
  # their instance IDs
  def load_ids_for_sub_models(model_name, ids)
    # Limitation: Same association can't appear twice
    includes_tree = includes_helper.get_tree_for(model_name)
    all_models = includes_helper.all_models(model_name)

    relation = model_name.classify.constantize.all.eager_load(includes_tree)

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
    instance_ids = relation.pluck(*pluck_args)

    # pluck returns only a 1D array if only 1 arg passed
    if all_models.size == 1
      instance_ids = [instance_ids]
    end

    return { model_names: all_models, instance_ids: instance_ids }
  end

  # 'posts', [post#1, post#2,...]
  def set_ids_for_sub_models(model_name = model, ids = nil, enforce: false)
    edge_set = load_ids_for_sub_models(model_name, ids)

    # Build the tree
    id_changeset = graph_helper.apply_update({
      add: [edge_set]
    })
    apply_id_changeset(id_changeset)
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

  def add(model_name, instance_id)
    idx = $redis_jason.incr("jason:subscription:#{id}:#{model_name}:idx")
    payload = JSON.parse($redis_jason.hget("jason:cache:#{model_name}", instance_id) || '{}')

    payload = {
      id: instance_id,
      model: model_name,
      payload: payload,
      md5Hash: id,
      idx: idx.to_i
    }

    ActionCable.server.broadcast(channel, payload)
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
    idx = $redis_jason.incr("jason:subscription:#{id}:#{model_name}:idx")

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
