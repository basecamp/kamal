require "bundler/setup"
require "active_support/test_case"
require "active_support/testing/autorun"
require "debug"
require "sshkit"

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["VERBOSE"]

SSHKit.config.backend = SSHKit::Backend::Printer

class ActiveSupport::TestCase
end
