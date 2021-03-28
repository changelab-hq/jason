# Configure spec_helper.rb
ENV["RAILS_ENV"] = "test"
require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rspec/rails'
require "jason"
require 'pry'

ENGINE_RAILS_ROOT=File.join(File.dirname(__FILE__), '../')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(ENGINE_RAILS_ROOT, "spec/support/**/*.rb")].each {|f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate

  config.before(:all) do
    Jason.setup do |config|
      config.schema = {
        post: {
          subscribed_fields: [:id, :name]
        },
        comment: {
          subscribed_fields: [:id, :body, :post_id, :user_id, :moderating_user_id, :created_at]
        },
        user: {
          subscribed_fields: [:id]
        },
        like: {
          subscribed_fields: [:id, :user_id, :comment_id]
        },
        role: {
          subscribed_fields: [:id, :user_id, :name]
        }
      }
    end
  end

  config.before(:each) do
    $redis_jason.flushdb
  end
  config.after(:each) do

  end
end