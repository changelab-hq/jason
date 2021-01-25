class Post < ApplicationRecord
  include Jason::Publisher

  has_many :comments

end