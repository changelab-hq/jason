class Jason::Broadcaster
  attr_reader :channel

  def initialize(channel)
    @channel = channel
  end

  def pusher_channel_name
    "private-#{Jason.pusher_channel_prefix}-#{channel}"
  end

  def broadcast(message)
    if Jason.transport_service == :action_cable
      ActionCable.server.broadcast(channel, message)
    elsif Jason.transport_service == :pusher
      Jason.pusher.trigger(pusher_channel_name, 'changed', message)
    end
  end
end