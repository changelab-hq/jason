RSpec.describe "API Update Requests", type: 'request' do

end

class TestUpdateAuthorizationService
  attr_reader :user, :model, :action, :instance, :params

  def self.call(...)
    new(...).call
  end

  def initialize(user, model, action, instance, params)
    @user = user
    @model = model
    @action = action
    @instance = instance
    @params = params
  end

  def call
    return false if user.blank?
    if user.roles.map(&:name).include?('admin')
      return true
    elsif user.roles.map(&:name).include?('user')
      return can_user_access?
    else
      return false
    end
  end

  def can_user_access?
    if model == 'post'
      if sub_models.blank?
        return true
      else
        return false
      end
    elsif model == 'comment'
      if conditions.blank?
        return false
      else
        if Comment.find(conditions['id']).user_id == user.id
          if (sub_models - ['like']).blank?
            return true
          else
            return false
          end
        else
          return false
        end
      end
    else
      return false
    end

    return false
  end
end