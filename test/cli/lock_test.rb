require_relative "cli_test_case"

class CliLockTest < CliTestCase
  test "status" do
    run_command("status") do |output|
      assert_match "stat lock", output
    end
  end

  test "release" do
    run_command("release") do |output|
      assert_match "rm -rf lock", output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Lock.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
