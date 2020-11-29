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
          transmit(subscription.get(model))
        end
        stream_from subscription.channel
      elsif (config = message['removeSubscription'])
        subscription = Jason::Subscription.new(config: config)
        subscriptions.reject! { |s| s.id == subscription.id }
        subscription.add_consumer(identifier)
        stop_stream_from subscription.channel
      elsif (model = message['getPayload'])
        subscriptions.each do |s|
          transmit(s.get(model))
        end
      end
    rescue => e
      puts e.message
      puts e.backtrace
      raise e
    end
  end
end
