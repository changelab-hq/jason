class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  before_save :add_id
  def add_id
    self.id ||= SecureRandom.uuid
  end
end
