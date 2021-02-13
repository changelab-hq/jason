 class Jason::Api::PusherController < ApplicationController
  skip_before_action :verify_authenticity_token

  def auth
    channel_main_name = params[:channel_name].remove("private-#{Jason.pusher_channel_prefix}-")
    subscription_id = channel_main_name.remove('jason-')

    if Jason::Subscription.find_by_id(subscription_id).user_can_access?(current_user)
      response = Pusher.authenticate(params[:channel_name], params[:socket_id])
      return render json: response
    else
      return head :forbidden
    end
  end
end
