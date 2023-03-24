require_relative "cli_test_case"

class CliHealthcheckTest < CliTestCase
  test "perform" do
    # Prevent expected failures from outputting to terminal
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.stubs(:sleep) # No sleeping when retrying
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :stop, raise_on_non_zero_exit: false)
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :run, "--detach", "--name", "healthcheck-app-999", "--publish", "3999:3000", "--label", "service=healthcheck-app", "-e", "MRSK_CONTAINER_NAME=\"healthcheck-app\"", "dhh/app:999")
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :container, :rm, raise_on_non_zero_exit: false)

    # Fail twice to test retry logic
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:curl, "--silent", "--output", "/dev/null", "--write-out", "'%{http_code}'", "--max-time", "2", "http://localhost:3999/up")
      .raises(SSHKit::Command::Failed)
      .then
      .raises(SSHKit::Command::Failed)
      .then
      .returns("200")

    run_command("perform").tap do |output|
      assert_match "Health check against /up failed to respond, retrying in 1s...", output
      assert_match "Health check against /up failed to respond, retrying in 2s...", output
      assert_match "Health check against /up succeeded with 200 OK!", output
    end
  end

  test "perform failing because of curl" do
    # Prevent expected failures from outputting to terminal
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.stubs(:execute) # No need to execute anything here
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:curl, "--silent", "--output", "/dev/null", "--write-out", "'%{http_code}'", "--max-time", "2", "http://localhost:3999/up")
      .returns("curl: command not found")
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :logs, "--tail", 50, "2>&1")

    exception = assert_raises SSHKit::Runner::ExecuteError do
      run_command("perform")
    end
    assert_match "Health check against /up failed to return 200 OK!", exception.message
  end

  test "perform failing for unknown reason" do
    # Prevent expected failures from outputting to terminal
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.stubs(:execute) # No need to execute anything here
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:curl, "--silent", "--output", "/dev/null", "--write-out", "'%{http_code}'", "--max-time", "2", "http://localhost:3999/up")
      .returns("500")
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :logs, "--tail", 50, "2>&1")

    exception = assert_raises do
      run_command("perform")
    end
    assert_match "Health check against /up failed with status 500", exception.message
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Healthcheck.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
