require 'connection_pool'
require 'redis'
require 'jsondiff'

require "jason/version"
require 'jason/api_model'
require 'jason/channel'
require 'jason/publisher'
require 'jason/subscription'
require 'jason/broadcaster'
require 'jason/engine'
require 'jason/lua_generator'
require 'jason/includes_helper'
require 'jason/graph_helper'
require 'jason/conditions_matcher'
require 'jason/consistency_checker'

module Jason
  class Error < StandardError; end

  self.mattr_accessor :schema
  self.mattr_accessor :transport_service
  self.mattr_accessor :redis
  self.mattr_accessor :pusher
  self.mattr_accessor :pusher_key
  self.mattr_accessor :pusher_region
  self.mattr_accessor :pusher_channel_prefix
  self.mattr_accessor :subscription_authorization_service
  self.mattr_accessor :update_authorization_service
  self.mattr_accessor :sidekiq_queue

  self.schema = {}
  self.transport_service = :action_cable
  self.pusher_region = 'eu'
  self.pusher_channel_prefix = 'jason'
  self.sidekiq_queue = 'default'

  def self.init
    # Don't run in AR migration / generator etc.
    return if $PROGRAM_NAME == '-e' || ActiveRecord::Base.connection.migration_context.needs_migration?

    # Check if the schema has changed since last time app was started. If so, do some work to ensure cache contains the correct data
    got_lock = $redis_jason.set('jason:schema:lock', '1', nx: true, ex: 3600) # Basic lock mechanism for multi-process environments
    return if !got_lock

    previous_schema = JSON.parse($redis_jason.get('jason:last_schema') || '{}')
    current_schema = Jason.schema.deep_stringify_keys.deep_transform_values { |v| v.is_a?(Symbol) ? v.to_s : v }
    current_schema.each do |model, config|
      if config != previous_schema[model]
        puts "Config changed for #{model}"
        puts "Old config was #{previous_schema[model]}"
        puts "New config is #{config}"
        puts "Wiping cache for #{model}"

        $redis_jason.del("jason:cache:#{model}")
        puts "Done"
      end
    end

    $redis_jason.set('jason:last_schema', current_schema.to_json)
  ensure
    $redis_jason.del('jason:schema:lock')
  end


  # this function maps the vars from your app into your engine
  def self.setup(&block)
    yield self

    $redis_jason = self.redis || ::ConnectionPool::Wrapper.new(size: 5, timeout: 3) { ::Redis.new(url: ENV['REDIS_URL']) }

    if ![:action_cable, :pusher].include?(self.transport_service)
      raise "Unknown transport service '#{self.transport_service}' specified"
    end

    if self.transport_service == :pusher && self.pusher.blank?
      raise "Pusher specified as transport service but no Pusher client provided. Please configure with config.pusher = Pusher::Client.new(...)"
    end

    init
  end
end
