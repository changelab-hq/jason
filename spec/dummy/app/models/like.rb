class Like < ApplicationRecord
  include Jason::Publisher

  belongs_to :comment
  belongs_to :user

end