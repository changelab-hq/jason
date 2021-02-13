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

module Jason
  class Error < StandardError; end

  self.mattr_accessor :schema
  self.mattr_accessor :transport_service
  self.mattr_accessor :redis
  self.mattr_accessor :pusher
  self.mattr_accessor :pusher_key
  self.mattr_accessor :pusher_region
  self.mattr_accessor :pusher_channel_prefix
  self.mattr_accessor :authorization_service

  self.schema = {}
  self.transport_service = :action_cable
  self.pusher_region = 'eu'
  self.pusher_channel_prefix = 'jason'

  # add default values of more config vars here

  # this function maps the vars from your app into your engine
  def self.setup(&block)
    yield self
  end

  $redis_jason = self.redis || ::ConnectionPool::Wrapper.new(size: 5, timeout: 3) { ::Redis.new(url: ENV['REDIS_URL']) }

  if ![:action_cable, :pusher].include?(self.transport_service)
    raise "Unknown transport service '#{self.transport_service}' specified"
  end

  if self.transport_service == :pusher && self.pusher.blank?
    raise "Pusher specified as transport service but no Pusher client provided. Please configure with config.pusher = Pusher::Client.new(...)"
  end
end
