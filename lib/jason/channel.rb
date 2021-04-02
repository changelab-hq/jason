class Jason::Channel < ActionCable::Channel::Base
  attr_accessor :subscriptions

  def subscribe
    stream_from 'jason'
  end

  def receive(message)
    handle_message(message)
  end

  private

  def handle_message(message)
    @subscriptions ||= []

    begin # ActionCable swallows errors in this message - ensure they're output to logs.
      if (config = message['createSubscription'])
        create_subscription(config['model'], config['conditions'], config['includes'])
      elsif (config = message['removeSubscription'])
        remove_subscription(config)
      elsif (config = message['getPayload'])
        get_payload(config, message['forceRefresh'])
      end
    rescue => e
      puts e.message
      puts e.backtrace
      raise e
    end
  end

  def create_subscription(model, conditions, includes)
    subscription = Jason::Subscription.upsert_by_config(model, conditions: conditions || {}, includes: includes || nil)

    return if !subscription.user_can_access?(current_user)
    stream_from subscription.channel

    subscriptions.push(subscription)
    subscription.add_consumer(identifier)
  end

  def remove_subscription(config)
    subscription = Jason::Subscription.upsert_by_config(config['model'], conditions: config['conditions'], includes: config['includes'])
    subscriptions.reject! { |s| s.id == subscription.id }
    subscription.remove_consumer(identifier)
  end

  def get_payload(config, force_refresh = false)
    subscription = Jason::Subscription.upsert_by_config(config['model'], conditions: config['conditions'], includes: config['includes'])

    return if !subscription.user_can_access?(current_user)
    if force_refresh
      subscription.set_ids_for_sub_models
    end
    subscription.get.each do |model_name, payload|
      transmit(payload) if payload.present?
    end
  end
end
