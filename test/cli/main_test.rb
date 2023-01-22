require "test_helper"
require "active_support/testing/stream"
require "mrsk/cli"

class CliMainTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  setup do
  end

  test "version" do
    version = stdouted { Mrsk::Cli::Main.new.version }
    assert_equal Mrsk::VERSION, version
  end
end
