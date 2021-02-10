class Role < ApplicationRecord
  include Jason::Publisher

  belongs_to :user
end