module Jason::Publisher
  extend ActiveSupport::Concern

  def cache_json
    as_json_config = api_model.as_json_config
    scope = api_model.scope

    if self.persisted? && (scope.blank? || self.class.unscoped.send(scope).exists?(self.id))
      payload = self.reload.as_json(as_json_config)
      $redis.hset("jason:#{self.class.name.underscore}:cache", self.id, payload.to_json)
    else
      $redis.hdel("jason:#{self.class.name.underscore}:cache", self.id)
    end
  end

  def publish_json
    cache_json
    return if skip_publish_json
    subscriptions = $redis.hgetall("jason:#{self.class.name.underscore}:subscriptions")
    subscriptions.each do |id, config_json|
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
      $redis.hgetall("jason:#{self.name.underscore}:subscriptions")
    end

    def publish_all(instances)
      instances.each(&:cache_json)

      subscriptions.each do |id, config_json|
        Jason::Subscription.new(id: id).update(self.name.underscore)
      end
    end

    def flush_cache
      $redis.del("jason:#{self.name.underscore}:cache")
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
  end

  included do
    attr_accessor :skip_publish_json, :api_model

    setup_json
  end
end
