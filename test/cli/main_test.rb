require "test_helper"
require "active_support/testing/stream"
require "mrsk/cli"

class CommandsAppTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  setup do
  end

  test "version" do
    version = capture(:stdout) { Mrsk::Cli::Main.new.version }.strip
    assert_equal Mrsk::VERSION, version
  end
end
