module Jason::Publisher
  extend ActiveSupport::Concern

  # Warning: Could be expensive. Mainly useful for rebuilding cache after changing Jason config or on deploy
  def self.cache_all
    Rails.application.eager_load!
    ActiveRecord::Base.descendants.each do |klass|
      $redis_jason.del("jason:cache:#{klass.name.underscore}")
      klass.cache_all if klass.respond_to?(:cache_all)
    end
  end

  def cache_json
    as_json_config = api_model.as_json_config
    scope = api_model.scope

    # Exists
    if self.persisted? && (scope.blank? || self.class.unscoped.send(scope).exists?(self.id))
      payload = self.as_json(as_json_config)
      gidx = Jason::LuaGenerator.new.cache_json(self.class.name.underscore, self.id, payload)
      return [payload, gidx]
    # Has been destroyed
    else
      $redis_jason.hdel("jason:cache:#{self.class.name.underscore}", self.id)
      return []
    end
  end

  def force_publish_json
    # As-if newly created
    publish_json(self.attributes.map { |k,v| [k, [nil, v]] }.to_h)
  end

  def publish_json(previous_changes = {})
    payload, gidx = cache_json

    return if skip_publish_json
    subs = jason_subscriptions # Get this first, because could be changed

    # Situations where IDs may need to change and this can't be immediately determined
    # - An instance is created where it belongs_to an instance under a subscription
    # - An instance belongs_to association changes - e.g. comment.post_id changes to/from one with a subscription
    # - TODO: The value of an instance changes so that it enters/leaves a subscription

    # TODO: Optimize this, by caching associations rather than checking each time instance is saved
    jason_assocs = self.class.reflect_on_all_associations(:belongs_to)
      .reject { |assoc| assoc.polymorphic? } # Can't get the class name of a polymorphic association, by
      .select { |assoc| assoc.klass.respond_to?(:has_jason?) }
    jason_assocs.each do |assoc|
      if previous_changes[assoc.foreign_key].present?
        Jason::Subscription.update_ids(
          self.class.name.underscore,
          id,
          assoc.name.to_s.singularize,
          previous_changes[assoc.foreign_key][0],
          previous_changes[assoc.foreign_key][1]
        )
      elsif (persisted? && @was_a_new_record && send(assoc.foreign_key).present?)
        Jason::Subscription.update_ids(
          self.class.name.underscore,
          id,
          assoc.name.to_s.singularize,
          nil,
          send(assoc.foreign_key)
        )
      end
    end

    if !persisted? # Deleted
      Jason::Subscription.remove_ids(
        self.class.name.underscore,
        [id]
       )
    end

    if persisted?
      applied_sub_ids = []

      jason_conditions.each do |row|
        matches = row['conditions'].map do |key, rules|
          Jason::ConditionsMatcher.new(self.class).test_match(key, rules, previous_changes)
        end
        next if matches.all? { |m| m.nil? } # None of the keys were in previous changes - therefore this condition does not apply
        in_sub = matches.all? { |m| m }

        if in_sub
          row['subscription_ids'].each do |sub_id|
            Jason::Subscription.find_by_id(sub_id).add_id(self.class.name.underscore, self.id)
            applied_sub_ids.push(sub_id)
          end
        else
          row['subscription_ids'].each do |sub_id|
            jason_subscriptions.each do |already_sub_id|
              # If this sub ID already has this instance, remove it
              if already_sub_id == sub_id
                sub = Jason::Subscription.find_by_id(already_sub_id)
                sub.remove_id(self.class.name.underscore, self.id)
                applied_sub_ids.push(already_sub_id)
              end
            end
          end
        end
      end

      jason_subscriptions.each do |sub_id|
        next if applied_sub_ids.include?(sub_id)

        Jason::Subscription.new(id: sub_id).update(self.class.name.underscore, id, payload, gidx)
      end
    end
  end

  def publish_json_if_changed
    subscribed_fields = api_model.subscribed_fields
    publish_json(self.previous_changes) if (self.previous_changes.keys.map(&:to_sym) & subscribed_fields).present? || !self.persisted?
  end

  def jason_subscriptions
    Jason::Subscription.for_instance(self.class.name.underscore, id)
  end

  def jason_conditions
    Jason::Subscription.conditions_for_model(self.class.name.underscore)
  end

  def jason_cached_value
    JSON.parse($redis_jason.get("jason:cache:#{self.class.name.underscore}:#{id}") || '{}')
  end

  class_methods do
    def cache_all
      all.find_each(&:cache_json)
    end

    def cache_for(ids)
      where(id: ids).find_each(&:cache_json)
    end

    def has_jason?
      true
    end

    def flush_cache
      $redis_jason.del("jason:cache:#{self.name.underscore}")
    end

    def setup_json
      self.before_save -> {
        @was_a_new_record = new_record?
      }
      self.after_initialize -> {
        @api_model = Jason::ApiModel.new(self.class.name.underscore)
      }
      self.after_commit :force_publish_json, on: [:create, :destroy]
      self.after_commit :publish_json_if_changed, on: [:update]
    end
  end

  included do
    attr_accessor :skip_publish_json, :api_model

    setup_json
  end
end
