require "test_helper"
require "active_support/testing/stream"

class CliTestCase < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  setup do
    ENV["VERSION"]             = "999"
    ENV["RAILS_MASTER_KEY"]    = "123"
    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
    ENV.delete("MYSQL_ROOT_PASSWORD")
    ENV.delete("VERSION")
    MRSK.reset
  end

  private
    def stdouted
      capture(:stdout) { yield }.strip
    end
end
