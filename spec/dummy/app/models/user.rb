class User < ApplicationRecord
  include Jason::Publisher

  has_many :likes
  has_many :comments
  has_many :roles
end