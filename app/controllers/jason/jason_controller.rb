class Jason::JasonController < ::ApplicationController
  before_action :load_and_authorize_subscription, only: [:create_subscription, :remove_subscription, :get_payload]
  # config seems to be a reserved name, resulting in infinite loop
  def configuration
    payload = {
      schema: Jason.schema,
      transportService: Jason.transport_service,
    }

    if Jason.transport_service == :pusher
      payload.merge!({
        pusherKey: Jason.pusher_key,
        pusherRegion: Jason.pusher_region,
        pusherChannelPrefix: Jason.pusher_channel_prefix
      })
    end

    render json: payload
  end

  def action
    type = params[:type]
    entity = type.split('/')[0].underscore
    api_model = Jason::ApiModel.new(entity.singularize)
    model = entity.singularize.camelize.constantize
    action = type.split('/')[1].underscore

    if action == 'move_priority'
      id, priority = params[:payload].values_at(:id, :priority)

      instance = model.find(id)
      priority_filter = instance.as_json.with_indifferent_access.slice(*api_model.priority_scope)

      all_instance_ids = model.send(api_model.scope || :all).where(priority_filter).where.not(id: instance.id).order(:priority).pluck(:id)
      all_instance_ids.insert(priority.to_i, instance.id)

      all_instance_ids.each_with_index do |id, i|
        model.find(id).update!(priority: i)
      end

      model.find(all_instance_ids).each(&:force_publish_json)
    elsif action == 'upsert' || action == 'add'
      payload = api_model.permit(params)
      return render json: model.find_or_create_by_id!(payload).as_json(api_model.as_json_config)
    elsif action == 'remove'
      model.find(params[:payload]).destroy!
    end

    return head :ok
  end

  def create_subscription
    @subscription.add_consumer(params[:consumer_id])
    render json: { channelName: @subscription.channel }
  end

  def remove_subscription
    @subscription.remove_consumer(params[:consumer_id])
  end

  def get_payload
    if params[:options].try(:[], :force_refresh)
      @subscription.set_ids_for_sub_models
    end

    render json: @subscription.get
  end

  private

  def load_and_authorize_subscription
    config = params[:config].to_unsafe_h
    @subscription = Jason::Subscription.upsert_by_config(config['model'], conditions: config['conditions'], includes: config['includes'])
    if !@subscription.user_can_access?(current_user)
      return head :forbidden
    end
  end
end
