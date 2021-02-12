class Comment < ApplicationRecord
  include Jason::Publisher

  belongs_to :post
  belongs_to :user, optional: true
  belongs_to :moderating_user, optional: true, class_name: 'User'
  has_many :likes

end