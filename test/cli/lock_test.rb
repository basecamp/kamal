require_relative "cli_test_case"

class CliLockTest < CliTestCase
  test "status" do
    run_command("status").tap do |output|
      assert_match "Running /usr/bin/env stat .kamal/lock-app > /dev/null && cat .kamal/lock-app/details | base64 -d on 1.1.1.1", output
    end
  end

  test "release" do
    run_command("release").tap do |output|
      assert_match "Released the deploy lock", output
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Lock.start([ *command, "-v", "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
