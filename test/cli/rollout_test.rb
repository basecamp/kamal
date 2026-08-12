require_relative "cli_test_case"

class CliRolloutTest < CliTestCase
  test "boot registers rollout targets and leaves them disabled" do
    stub_rollout_booting

    run_command("boot").tap do |output|
      assert_match "docker run --detach --restart unless-stopped --name app-web-rollout-999", output
      assert_match "--env KAMAL_ROLLOUT=\"1\"", output
      assert_match "--memory \"2g\"", output
      assert_match "--env RAILS_ENV=\"rollout\"", output
      assert_match "--label role=\"web-rollout\"", output

      assert_match "docker exec kamal-proxy kamal-proxy rollout deploy app-web --target=", output
      assert_match "docker exec kamal-proxy kamal-proxy rollout disable app-web", output
    end
  end

  test "boot disables before registering the new targets" do
    stub_rollout_booting

    run_command("boot").tap do |output|
      assert_operator output.index("rollout disable app-web"), :<, output.index("rollout deploy app-web"),
        "a new rollout must not inherit traffic from the split that was already open"
    end
  end

  test "boot leaves the live containers and the latest tag alone" do
    stub_rollout_booting

    run_command("boot").tap do |output|
      assert_no_match "docker tag", output
      assert_no_match(/kamal-proxy deploy app-web /, output)
      assert_no_match "--name app-web-999", output
    end
  end

  test "boot uses the rollout hosts and command for a role that is not proxied" do
    stub_rollout_booting

    run_command("boot").tap do |output|
      assert_match "docker run --detach --restart unless-stopped --name app-workers-rollout-999", output
      assert_match "bin/jobs --rollout", output
      assert_match "on 1.1.1.4", output
    end
  end

  test "boot leaves it enabled when on_boot is keep" do
    stub_rollout_booting

    run_command("boot", fixture: :with_rollout_keeping_split).tap do |output|
      assert_match "docker run --detach --restart unless-stopped --name app-web-rollout-999", output
      assert_no_match "kamal-proxy rollout disable", output
    end
  end

  test "set percent" do
    run_command("set", "--percent", "5").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy rollout set app-web --percent=\"5\"", output
    end
  end

  test "set list" do
    run_command("set", "--list", "1234", "5678").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy rollout set app-web --list=\"1234\" --list=\"5678\"", output
    end
  end

  test "disable turns traffic off without unregistering" do
    run_command("disable").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy rollout disable app-web", output
      assert_no_match "kamal-proxy rollout stop", output
      assert_no_match "kamal-proxy rollout set", output
    end
  end

  test "enable turns traffic back on without a percentage" do
    run_command("enable").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy rollout enable app-web", output
      assert_no_match "kamal-proxy rollout set", output
    end
  end

  test "enable and disable do not wait on the deploy lock" do
    run_command("disable").tap { |output| assert_no_match "Acquiring the deploy lock", output }
    run_command("enable").tap { |output| assert_no_match "Acquiring the deploy lock", output }
  end

  test "set takes the deploy lock" do
    run_command("set", "--percent", "5").tap { |output| assert_match "Acquiring the deploy lock", output }
  end

  test "set only touches proxied roles" do
    run_command("set", "--percent", "5").tap do |output|
      assert_no_match "app-workers", output
    end
  end

  test "set refuses a percent above max_percent" do
    error = assert_raises(Kamal::ConfigurationError) do
      run_command("set", "--percent", "50")
    end

    assert_match "exceeds rollout/max_percent of 25", error.message
  end

  test "set requires percent or list" do
    assert_raises(Kamal::ConfigurationError) { run_command("set") }
  end

  test "remove unregisters then removes the containers" do
    run_command("remove", "-y").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy rollout stop app-web", output
      assert_match "docker container prune --force --filter label=service=app --filter label=destination= --filter label=role=web-rollout", output
      assert_match "docker container prune --force --filter label=service=app --filter label=destination= --filter label=role=workers-rollout", output
    end
  end

  test "details summarises the split and the container counts" do
    listed = {
      services: {
        "app-web" => {
          rollout_target: "172.17.0.5:80", rollout_percentage: 5,
          rollout_allowlist: [ "1234" ], rollout_enabled: true
        }
      }
    }.to_json

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns(listed)

    run_command("details").tap do |output|
      assert_match "Split     5%, list of 1, enabled -> 172.17.0.5:80", output
      assert_match "web       2/2 running", output
      assert_match "workers   1/1 running", output
      # One line for the split, not one per host
      assert_equal 1, output.scan("Split ").size
    end
  end

  test "split summary reads the proxy listing" do
    listed = ->(service) { { services: { "app-web" => service } }.to_json }

    assert_equal "5%, enabled -> 1.2.3.4:80",
      Kamal::Cli::Rollout.split_summary(listed.call(rollout_target: "1.2.3.4:80", rollout_percentage: 5, rollout_enabled: true), "app-web")

    assert_equal "2%, disabled -> 1.2.3.4:80",
      Kamal::Cli::Rollout.split_summary(listed.call(rollout_target: "1.2.3.4:80", rollout_percentage: 2, rollout_enabled: false), "app-web")

    assert_equal "no split set, disabled -> 1.2.3.4:80",
      Kamal::Cli::Rollout.split_summary(listed.call(rollout_target: "1.2.3.4:80"), "app-web")

    assert_equal "none registered", Kamal::Cli::Rollout.split_summary(listed.call({}), "app-web")
    assert_equal "none registered", Kamal::Cli::Rollout.split_summary("{}", "app-web")
    assert_equal "none registered", Kamal::Cli::Rollout.split_summary("", "app-web")
    assert_equal "could not be read", Kamal::Cli::Rollout.split_summary("not json", "app-web")
  end

  test "details reports nothing when rollouts are not configured" do
    run_command("details", fixture: :simple).tap do |output|
      assert_match "No roles take part in rollouts", output
    end
  end

  test "deploy keeps a live rollout and says so" do
    stub_deploy_invocations

    run_deploy.tap do |output|
      assert_match "Rollout still live (web at 1234, workers at 1234). This deploy leaves it alone", output
      assert_no_match "kamal-proxy rollout disable", output
    end
  end

  test "deploy disables a live rollout when on_deploy says so" do
    stub_deploy_invocations

    run_deploy(fixture: :with_rollout_disabling).tap do |output|
      assert_match "Rollout still live (web at 1234, workers at 1234). Disabling it.", output
      assert_match "docker exec kamal-proxy kamal-proxy rollout disable app-web", output
    end
  end

  test "deploy says nothing when no rollout is running" do
    stub_deploy_invocations
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("")

    run_deploy.tap do |output|
      assert_no_match "Rollout still live", output
    end
  end

  private
    def stub_deploy_invocations
      Kamal::Cli::Main.any_instance.stubs(:invoke)
      Kamal::Cli::Main.any_instance.stubs(:run_hook)
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("1234")
    end

    def run_deploy(fixture: :with_rollout)
      with_argv([ "deploy", "-P", "-c", "test/fixtures/deploy_#{fixture}.yml" ]) do
        stdouted { Kamal::Cli::Main.start }
      end
    end

    def stub_rollout_booting
      Object.any_instance.stubs(:sleep)
      Kamal::Cli::Rollout.any_instance.stubs(:invoke)

      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("running")
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
        .with { |*args, **kwargs| kwargs[:raise_on_non_zero_exit] == false }
        .returns("")
    end

    def run_command(*command, fixture: :with_rollout)
      stdouted { Kamal::Cli::Rollout.start([ *command, "-c", "test/fixtures/deploy_#{fixture}.yml" ]) }
    end
end
