require_relative "cli_test_case"

class CliAppTest < CliTestCase
  test "boot" do
    assert_match /Running docker run -d --restart unless-stopped/, run_command("boot")
  end

  test "reboot" do
    run_command("reboot").tap do |output|
      assert_match /docker stop/, output
      assert_match /docker container prune/, output
      assert_match /docker run -d --restart unless-stopped/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::App.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
