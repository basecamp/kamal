require_relative "cli_test_case"

class CliHealthcheckTest < CliTestCase
  test "perform" do
    # Prevent expected failures from outputting to terminal
    Thread.report_on_exception = false

    Mrsk::Utils::HealthcheckPoller.stubs(:sleep) # No sleeping when retrying

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :stop, raise_on_non_zero_exit: false)
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :run, "--detach", "--name", "healthcheck-app-999", "--publish", "3999:3000", "--label", "service=healthcheck-app", "-e", "MRSK_CONTAINER_NAME=\"healthcheck-app\"", "--health-cmd", "\"curl -f http://localhost:3000/up || exit 1\"", "--health-interval", "\"1s\"", "dhh/app:999")
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :container, :rm, raise_on_non_zero_exit: false)

    # Fail twice to test retry logic
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("starting")
      .then
      .returns("unhealthy")
      .then
      .returns("healthy")

    run_command("perform").tap do |output|
      assert_match "container not ready (starting), retrying in 1s (attempt 1/7)...", output
      assert_match "container not ready (unhealthy), retrying in 2s (attempt 2/7)...", output
      assert_match "Container is healthy!", output
    end
  end

  test "perform failing to become healthy" do
    # Prevent expected failures from outputting to terminal
    Thread.report_on_exception = false

    Mrsk::Utils::HealthcheckPoller.stubs(:sleep) # No sleeping when retrying

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :stop, raise_on_non_zero_exit: false)
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :run, "--detach", "--name", "healthcheck-app-999", "--publish", "3999:3000", "--label", "service=healthcheck-app", "-e", "MRSK_CONTAINER_NAME=\"healthcheck-app\"", "--health-cmd", "\"curl -f http://localhost:3000/up || exit 1\"", "--health-interval", "\"1s\"", "dhh/app:999")
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :container, :rm, raise_on_non_zero_exit: false)

    # Continually report unhealthy
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("unhealthy")

    # Capture logs when failing
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :logs, "--tail", 50, "2>&1")
      .returns("some log output")

    # Capture container health log when failing
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_pretty_json)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^healthcheck-app-999$", "--quiet", "|", :xargs, :docker, :inspect, "--format",  "'{{json .State.Health}}'")
      .returns('{"Status":"unhealthy","Log":[{"ExitCode": 1,"Output": "/bin/sh: 1: curl: not found\n"}]}"')

    exception = assert_raises do
      run_command("perform")
    end
    assert_match "container not ready (unhealthy)", exception.message
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Healthcheck.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
