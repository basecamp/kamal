require "test_helper"
require "active_support/testing/stream"
require "mrsk/cli"

class CliAppTest < ActiveSupport::TestCase
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
  end

  test "boot" do
    assert_match /Running docker run -d --restart unless-stopped --name app-999/, run_command("boot")
  end

  test "reboot" do
    assert_equal "", run_command("reboot")
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::App.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
