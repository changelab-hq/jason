class Role < ApplicationRecord
  belongs_to :user

  include Jason::Publisher
end