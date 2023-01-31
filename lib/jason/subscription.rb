class Jason::Subscription
  attr_accessor :id, :config
  attr_reader :includes_helper, :graph_helper

  def initialize(id: nil, config: nil)
    if id
      @id = id
      raw_config = $redis_jason.hgetall("jason:subscriptions:#{id}").map { |k,v| [k, JSON.parse(v)] }.to_h
      raise "Subscription ID #{id} does not exist" if raw_config.blank?
      set_config(raw_config)
    else
      @id = Digest::MD5.hexdigest(config.sort_by { |key| key }.to_h.to_json)
      configure(config)
    end
    @includes_helper = Jason::IncludesHelper.new({ model => self.config['includes'] })
    @graph_helper = Jason::GraphHelper.new(self.id, @includes_helper)

    check_for_missing_keys
  end

  def broadcaster
    @broadcaster ||= Jason::Broadcaster.new(channel)
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

  def self.all_for_model(model_name)
    $redis_jason.smembers("jason:models:#{model_name}:all:subscriptions")
  end

  def self.for_instance(model_name, id, include_all = true)
    subs = $redis_jason.smembers("jason:models:#{model_name}:#{id}:subscriptions")
    if include_all
      subs += all_for_model(model_name)
    end
    subs
  end

  # returns [
  #   { condition: { post_id: 123 }, subscription_ids: [] }
  # ]
  def self.conditions_for_model(model_name)
    rows = $redis_jason.smembers("jason:models:#{model_name}:conditions").map do |row|
      JSON.parse(row)
    end
    conditions = rows.group_by { |row| row['conditions'] }
    conditions.map do |conditions, rows|
      { 'conditions' => conditions, 'subscription_ids' => rows.map { |row| row['subscription_id'] } }
    end
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

      # If foreign key has been nulled, nothing to add
      add = new_foreign_id.present? ? [
        {
          model_names: [changed_model_name, foreign_model_name],
          instance_ids: [[changed_model_id, new_foreign_id]]
        },
        # Add IDs of child models
        subscription.load_ids_for_sub_models(foreign_model_name, new_foreign_id)
      ] : nil

      id_changeset = subscription.graph_helper.apply_update(
        remove: [{
          model_names: [changed_model_name, foreign_model_name],
          instance_ids: [[changed_model_id, old_foreign_id]]
        }],
        add: add
      )

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
      subscription.graph_helper.apply_update(
        remove: [{
          model_names: [changed_model_name, foreign_model_name],
          instance_ids: [[changed_model_id, old_foreign_id]]
        }],
        add: [{
          model_names: [changed_model_name, foreign_model_name],
          instance_ids: [[changed_model_id, new_foreign_id]]
        }]
      )
    end

    #########
    # Subs where changed is child
    # + old parent wasn't in the sub, but new parent is
    # IE the changed instance is joining the sub
    # No edges are removed, just added
    (new_sub_ids - old_sub_ids).each do |sub_id|
      subscription = find_by_id(sub_id)
      id_changeset = subscription.graph_helper.apply_update(
        add: [
          {
            model_names: [changed_model_name, foreign_model_name],
            instance_ids: [[changed_model_id, new_foreign_id]]
          },
          # Add IDs of child models
          subscription.load_ids_for_sub_models(changed_model_name, changed_model_id)
        ]
      )

      subscription.apply_id_changeset(id_changeset)
      subscription.broadcast_id_changeset(id_changeset)
    end

    #########
    # --> Leaving the family
    # Subs where changed is child
    # + old parent was in the sub, but new parent isn't
    # Just need to remove the link, orphan detection will do the rest
    (old_sub_ids - new_sub_ids).each do |sub_id|
      subscription = find_by_id(sub_id)
      id_changeset = subscription.graph_helper.apply_update(
        remove: [
          {
            model_names: [changed_model_name, foreign_model_name],
            instance_ids: [[changed_model_id, old_foreign_id]]
          }
        ]
      )
      subscription.apply_id_changeset(id_changeset)
      subscription.broadcast_id_changeset(id_changeset)
    end

    #########
    # ---> Join the community
    # Subs where changed is parent + parent is an _all_ or _condition_ subscription

  end

  def self.remove_ids(model_name, ids)
    ids.each do |instance_id|
      for_instance(model_name, instance_id, false).each do |sub_id|
        subscription = find_by_id(sub_id)

        id_changeset = subscription.graph_helper.apply_remove_node("#{model_name}:#{instance_id}")
        subscription.apply_id_changeset(id_changeset)
        subscription.broadcast_id_changeset(id_changeset)
      end
    end

    all_for_model(model_name).each do |sub_id|
      subscription = find_by_id(sub_id)
      ids.each do |id|
        subscription.destroy(model_name, id)
      end
    end
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

  # Add IDs that aren't present
  def commit_ids(model_name, ids)
    $redis_jason.sadd("jason:subscriptions:#{id}:ids:#{model_name}", ids)
    ids.each do |instance_id|
      $redis_jason.sadd("jason:models:#{model_name}:#{instance_id}:subscriptions", id)
    end
  end

  def remove_id(model_name, id)
    id_changeset = graph_helper.apply_remove_node("#{model_name}:#{id}")
    apply_id_changeset(id_changeset)
    broadcast_id_changeset(id_changeset)
  end

  def add_id(model_name, id)
    id_changeset = graph_helper.apply_update(
      add: [
        {
          model_names: [model_name],
          instance_ids: [[id]]
        },
        # Add IDs of child models
        load_ids_for_sub_models(model_name, id)
      ]
    )

    apply_id_changeset(id_changeset)
    broadcast_id_changeset(id_changeset)
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
      elsif conditions.keys == ['id']
        relation = relation.where(conditions)
      else
        $redis_jason.sadd("jason:models:#{model_name}:conditions", {
          'conditions' => conditions,
          'subscription_id' => self.id
        }.to_json)
        relation = Jason::ConditionsMatcher.new(relation.klass).apply_conditions(relation, conditions)
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
      instance_ids = instance_ids.map { |id| [id] }
    end

    return { model_names: all_models, instance_ids: instance_ids }
  end

  # 'posts', [post#1, post#2,...]
  def set_ids_for_sub_models(model_name = model, ids = nil, enforce: false)
    edge_set = load_ids_for_sub_models(model_name, ids)
    # Build the tree
    id_changeset = graph_helper.apply_update(
      add: [edge_set],
      enforce: enforce
    )

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
    $redis_jason.del("jason:subscriptions:#{id}:graph")
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
      set_ids_for_sub_models(enforce: true)
    end
  end

  def remove_consumer(consumer_id)
    $redis_jason.srem("jason:subscriptions:#{id}:consumers", consumer_id)
    $redis_jason.hdel("jason:consumers", consumer_id)
  end

  def consumer_count
    $redis_jason.scard("jason:subscriptions:#{id}:consumers")
  end

  def channel
    "jason-#{id}"
  end

  def user_can_access?(user)
    # td: implement the authorization logic here
    return true if Jason.subscription_authorization_service.blank?
    Jason.subscription_authorization_service.call(user, model, conditions, includes_helper.all_models - [model])
  end

  def get
    includes_helper.all_models.map { |model_name| [model_name, get_for_model(model_name)] }.to_h
  end

  def get_for_model(model_name)
    instance_jsons, idx = Jason::LuaGenerator.new.get_payload(model_name, id)
    if idx == 'missing'
      # warm cache and then retry
      model_klass(model_name).cache_for(instance_jsons)
      instance_jsons, idx = Jason::LuaGenerator.new.get_payload(model_name, id)
    end

    if instance_jsons.any? { |json| json.blank? }
      raise Jason::MissingCacheError
    end

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

  # To be used as a fallback when some corruption of the subscription has taken place
  def reset!(hard: false)
    # Remove subscription state
    if hard
      clear_all_ids
    end

    set_ids_for_sub_models(enforce: true)
    includes_helper.all_models.each do |model_name|
      broadcaster.broadcast(get_for_model(model_name))
    end
  end

  def add(model_name, instance_id)
    idx = $redis_jason.incr("jason:subscription:#{id}:#{model_name}:idx")
    payload = JSON.parse($redis_jason.get("jason:cache:#{model_name}:#{instance_id}") || '{}')

    payload = {
      id: instance_id,
      model: model_name,
      payload: payload,
      md5Hash: id,
      idx: idx.to_i
    }

    broadcaster.broadcast(payload)
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

    broadcaster.broadcast(payload)
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

    broadcaster.broadcast(payload)
  end
end

class Jason::MissingCacheError < StandardError; end
