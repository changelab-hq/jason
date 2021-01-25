class Jason::ApiController < ::ApplicationController
  def schema
    render json: Jason.schema
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
        model.find(id).update!(priority: i, skip_publish_json: true)
      end

      model.publish_all(model.find(all_instance_ids))
    elsif action == 'upsert' || action == 'add'
      payload = api_model.permit(params)
      return render json: model.find_or_create_by_id!(payload).as_json(api_model.as_json_config)
    elsif action == 'remove'
      model.find(params[:payload]).destroy!
    end

    return head :ok
  end
end
