class Jason::Channel < ActionCable::Channel::Base
  attr_accessor :subscriptions

  def receive(message)
    subscriptions ||= []

    begin # ActionCable swallows errors in this message - ensure they're output to logs.
      if (config = message['createSubscription'])
        subscription = Jason::Subscription.new(config: config)
        subscriptions.push(subscription)
        subscription.add_consumer(identifier)
        config.keys.each do |model|
          transmit(subscription.get(model.to_s.underscore))
        end
        stream_from subscription.channel
      elsif (config = message['removeSubscription'])
        subscription = Jason::Subscription.new(config: config)
        subscriptions.reject! { |s| s.id == subscription.id }
        subscription.remove_consumer(identifier)

        # Rails for some reason removed stream_from, so we need to stop all and then restart the other streams
        stop_all_streams
        subscriptions.each do |s|
          stream_from s.channel
        end
      elsif (data = message['getPayload'])
        config = data.config
        model = data.model
        Jason::Subscription.new(config: config).get(model.to_s.underscore)
      end
    rescue => e
      puts e.message
      puts e.backtrace
      raise e
    end
  end
end
