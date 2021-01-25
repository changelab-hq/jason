class Comment < ApplicationRecord
  include Jason::Publisher

  belongs_to :post
  belongs_to :user
  has_many :likes

end