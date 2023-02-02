require "bundler/setup"
require "active_support/test_case"
require "active_support/testing/autorun"
require "debug"
require "sshkit"
require "zeitwerk"

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["VERBOSE"]

SSHKit.config.backend = SSHKit::Backend::Printer

class ActiveSupport::TestCase
  test "Zeitwerk compliance" do 
    loader = Zeitwerk::Loader.for_gem
    loader.setup

    begin
      loader.eager_load(force: true)
    rescue Zeitwerk::NameError => e
      flunk e.message
    else
      assert true
    end
  end
end
