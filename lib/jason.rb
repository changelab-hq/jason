require 'connection_pool'
require 'redis'
require 'jsondiff'

require "jason/version"
require 'jason/api_model'
require 'jason/channel'
require 'jason/publisher'
require 'jason/subscription'
require 'jason/engine'
require 'jason/lua_generator'
require 'jason/includes_helper'
require 'jason/graph_helper'

module Jason
  class Error < StandardError; end

  $redis_jason = ::ConnectionPool::Wrapper.new(size: 5, timeout: 3) { ::Redis.new(url: ENV['REDIS_URL']) }


   self.mattr_accessor :schema
   self.schema = {}
   # add default values of more config vars here

   # this function maps the vars from your app into your engine
   def self.setup(&block)
      yield self
   end

end
