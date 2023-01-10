require "bundler/setup"
require "active_support/test_case"
require "active_support/testing/autorun"
require "debug"

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["VERBOSE"]

class ActiveSupport::TestCase
end
