require_relative "cli_test_case"

class CliSecretsTest < CliTestCase
  test "login" do
    run_command("login").tap do |output|
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] as .*@localhost/, output
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] on 1.1.1.\d/, output
    end
  end

  test "fetch" do
    run_command("login", "-L").tap do |output|
      assert_no_match /docker login -u \[REDACTED\] -p \[REDACTED\] as .*@localhost/, output
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] on 1.1.1.\d/, output
    end
  end

  test "fetch_all" do
    run_command("login", "-R").tap do |output|
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] as .*@localhost/, output
      assert_no_match /docker login -u \[REDACTED\] -p \[REDACTED\] on 1.1.1.\d/, output
    end
  end

  test "extract" do
    run_command("logout").tap do |output|
      assert_match /docker logout as .*@localhost/, output
      assert_match /docker logout on 1.1.1.\d/, output
    end
  end

  test "logout skip local" do
    run_command("logout", "-L").tap do |output|
      assert_no_match /docker logout as .*@localhost/, output
      assert_match /docker logout on 1.1.1.\d/, output
    end
  end

  test "logout skip remote" do
    run_command("logout", "-R").tap do |output|
      assert_match /docker logout as .*@localhost/, output
      assert_no_match /docker logout on 1.1.1.\d/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Secrets.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
