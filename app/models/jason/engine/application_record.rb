module Jason
  module Engine
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
