class Jason::Channel < ApplicationCable::Channel
  attr_accessor :config

  def subscribed
    begin # ActionCable swallows errors in this message - ensure they're output to logs.
      @config = params[:config].deep_transform_keys { |key| key.underscore }
    rescue => e
      raise e
    end
  end

  def receive(message)
    begin # ActionCable swallows errors in this message - ensure they're output to logs.
      if message['type'] == 'get_payload'
        puts config.inspect
        subscription = Jason::Subscription.new(config: config)
        transmit(subscription.get)
        stream_from subscription.channel
      end
    rescue => e
      puts e.message
      puts e.backtrace
      raise e
    end
  end
end
