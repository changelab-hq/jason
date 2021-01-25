class User < ApplicationRecord
  include Jason::Publisher

  has_many :likes
  has_many :comments

end