module Jason::Publisher
  extend ActiveSupport::Concern

  # Warning: Could be expensive. Mainly useful for rebuilding cache after changing Jason config or on deploy
  def self.cache_all
    Rails.application.eager_load!
    ActiveRecord::Base.descendants.each do |klass|
      klass.cache_all if klass.respond_to?(:cache_all)
    end
  end

  def cache_json
    as_json_config = api_model.as_json_config
    scope = api_model.scope

    # Exists
    if self.persisted? && (scope.blank? || self.class.unscoped.send(scope).exists?(self.id))
      payload = self.reload.as_json(as_json_config)
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
    jason_assocs = self.class.reflect_on_all_associations(:belongs_to).select { |assoc| assoc.klass.respond_to?(:has_jason?) }
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

    # - An instance is created where it belongs_to an _all_ subscription
    if previous_changes['id'].present?
      Jason::Subscription.add_id(self.class.name.underscore, id)
    end

    if persisted?
      jason_subscriptions.each do |sub_id|
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

  class_methods do
    def cache_all
      all.each(&:cache_json)
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
      self.after_commit :publish_json_if_changed
    end

    def find_or_create_by_id(params)
      object = find_by(id: params[:id])

      if object
        object.update(params)
      elsif params[:hidden]
        return false ## If an object is passed with hidden = true but didn't already exist, it's safe to never create it
      else
        object = create!(params)
      end

      object
    end

    def find_or_create_by_id!(params)
      object = find_by(id: params[:id])

      if object
        object.update!(params)
      elsif params[:hidden]
        ## TODO: We're diverging from semantics of the Rails bang! methods here, which would normally either raise or return an object. Find a way to make this better.
        return false ## If an object is passed with hidden = true but didn't already exist, it's safe to never create it
      else
        object = create!(params)
      end

      object
    end
  end

  included do
    attr_accessor :skip_publish_json, :api_model

    setup_json
  end
end
