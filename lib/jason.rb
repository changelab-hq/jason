require 'connection_pool'
require 'redis'
require 'jsondiff'

require "jason/version"
require 'jason/api_model'
require 'jason/channel'
require 'jason/publisher'
require 'jason/subscription'
require 'jason/engine'

module Jason
  class Error < StandardError; end

  $redis_jason = ::ConnectionPool::Wrapper.new(size: 5, timeout: 3) { ::Redis.new(url: ENV['REDIS_URL']) }
end
