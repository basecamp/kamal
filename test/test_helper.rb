require "bundler/setup"
require "active_support/test_case"
require "active_support/testing/autorun"
require "active_support/testing/stream"
require "debug"
require "mocha/minitest" # using #stubs that can alter returns
require "minitest/autorun" # using #stub that take args
require "sshkit"
require "mrsk"

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["VERBOSE"]

# Applies to remote commands only.
SSHKit.config.backend = SSHKit::Backend::Printer

# Ensure local commands use the printer backend too.
# See https://github.com/capistrano/sshkit/blob/master/lib/sshkit/dsl.rb#L9
module SSHKit
  module DSL
    def run_locally(&block)
      SSHKit::Backend::Printer.new(SSHKit::Host.new(:local), &block).run
    end
  end
end

class ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  private
    def stdouted
      capture(:stdout) { yield }.strip
    end

    def stderred
      capture(:stderr) { yield }.strip
    end
end
