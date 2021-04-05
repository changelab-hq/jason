class ApplicationController < ActionController::Base
  def current_user
    User.order(:created_at).first
  end
end
