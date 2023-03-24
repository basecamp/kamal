require_relative "cli_test_case"

class CliRegistryTest < CliTestCase
  test "login" do
    run_command("login").tap do |output|
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] as .*@localhost/, output
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] on 1.1.1.\d/, output
    end
  end

  test "logout" do
    run_command("logout").tap do |output|
      assert_match /docker logout on 1.1.1.\d/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Registry.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
