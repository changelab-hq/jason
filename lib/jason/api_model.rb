class Jason::ApiModel
  cattr_accessor :models
  attr_accessor :model, :name

  def self.configure(models)
    @@models = models
  end

  def initialize(name)
    @name = name
    @model = OpenStruct.new(Jason.schema[name.to_sym])
  end

  def allowed_params
    model.allowed_params || []
  end

  def allowed_object_params
    model.allowed_object_params || []
  end

  def include_methods
    model.include_methods || []
  end

  def priority_scope
    model.priority_scope || []
  end

  def subscribed_fields
    model.subscribed_fields || []
  end

  def scope
    model.scope
  end

  def permit(params)
    params = params.require(:payload).permit(allowed_params).tap do |allowed|
      allowed_object_params.each do |key|
        allowed[key] = params[:payload][key].to_unsafe_h if params[:payload][key]
      end
    end
  end

  def as_json_config
    { only: subscribed_fields, methods: include_methods }
  end
end
