module Jason::PublisherOld
  extend ActiveSupport::Concern

  def cache_json
    as_json_config = api_model.as_json_config
    scope = api_model.scope

    if self.persisted? && (scope.blank? || self.class.unscoped.send(scope).exists?(self.id))
      payload = self.reload.as_json(as_json_config)
      $redis_jason.hset("jason:#{self.class.name.underscore}:cache", self.id, payload.to_json)
    else
      $redis_jason.hdel("jason:#{self.class.name.underscore}:cache", self.id)
    end
  end

  def publish_json
    cache_json
    return if skip_publish_json

    self.class.jason_subscriptions.each do |id, config_json|
      config = JSON.parse(config_json)

      if (config['conditions'] || {}).all? { |field, value| self.send(field) == value }
        Jason::Subscription.new(id: id).update(self.class.name.underscore)
      end
    end
  end

  def publish_json_if_changed
    subscribed_fields = api_model.subscribed_fields
    publish_json if (self.previous_changes.keys.map(&:to_sym) & subscribed_fields).present? || !self.persisted?
  end

  class_methods do
    def subscriptions
      $redis_jason.hgetall("jason:#{self.name.underscore}:subscriptions")
    end

    def jason_subscriptions
      $redis_jason.hgetall("jason:#{self.name.underscore}:subscriptions")
    end

    def publish_all(instances)
      instances.each(&:cache_json)

      subscriptions.each do |id, config_json|
        Jason::Subscription.new(id: id).update(self.name.underscore)
      end
    end

    def flush_cache
      $redis_jason.del("jason:#{self.name.underscore}:cache")
    end

    def setup_json
      self.after_initialize -> {
        @api_model = Jason::ApiModel.new(self.class.name.underscore)
      }
      self.after_commit :publish_json_if_changed

      include_models = Jason::ApiModel.new(self.name.underscore).include_models

      include_models.map do |assoc|
        puts assoc
        reflection = self.reflect_on_association(assoc.to_sym)
        reflection.klass.after_commit -> {
          subscribed_fields = Jason::ApiModel.new(self.class.name.underscore).subscribed_fields
          puts subscribed_fields.inspect

          if (self.previous_changes.keys.map(&:to_sym) & subscribed_fields).present?
            self.send(reflection.inverse_of.name)&.publish_json
          end
        }
      end
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
