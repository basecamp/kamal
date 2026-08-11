require_relative "cli_test_case"

class CliRolloutTest < CliTestCase
  test "boot registers rollout targets and resets the split" do
    stub_rollout_booting

    run_command("boot").tap do |output|
      assert_match "docker run --detach --restart unless-stopped --name app-web-rollout-latest", output
      assert_match "--env KAMAL_ROLLOUT=\"1\"", output
      assert_match "--memory \"2g\"", output
      assert_match "--env RAILS_ENV=\"rollout\"", output
      assert_match "--label role=\"web-rollout\"", output

      assert_match "docker exec kamal-proxy kamal-proxy rollout deploy app-web --target=", output
      assert_match "docker exec kamal-proxy kamal-proxy rollout stop app-web", output
    end
  end

  test "boot clears any open split before registering the new targets" do
    stub_rollout_booting

    run_command("boot").tap do |output|
      assert_operator output.index("rollout stop app-web"), :<, output.index("rollout deploy app-web"),
        "the split must be cleared before the new targets are registered, or stop would clear them again"
    end
  end

  test "boot leaves the live containers and the latest tag alone" do
    stub_rollout_booting

    run_command("boot").tap do |output|
      assert_no_match "docker tag", output
      assert_no_match(/kamal-proxy deploy app-web /, output)
      assert_no_match "--name app-web-latest", output
    end
  end

  test "boot uses the rollout hosts and command for a role that is not proxied" do
    stub_rollout_booting

    run_command("boot").tap do |output|
      assert_match "docker run --detach --restart unless-stopped --name app-workers-rollout-latest", output
      assert_match "bin/jobs --rollout", output
      assert_match "on 1.1.1.4", output
    end
  end

  test "boot keeps the split when on_boot is keep" do
    stub_rollout_booting

    run_command("boot", fixture: :with_rollout_keeping_split).tap do |output|
      assert_match "docker run --detach --restart unless-stopped --name app-web-rollout-latest", output
      assert_no_match "kamal-proxy rollout stop", output
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

  test "set percent 0 closes the split but leaves the rollout registered" do
    run_command("set", "--percent", "0").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy rollout set app-web --percent=\"0\"", output
      assert_no_match "kamal-proxy rollout stop", output
    end
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

  test "stop resets the split without removing containers" do
    run_command("stop").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy rollout stop app-web", output
      assert_no_match "docker container prune", output
    end
  end

  test "remove stops the split then removes the containers" do
    run_command("remove", "-y").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy rollout stop app-web", output
      assert_match "docker container prune --force --filter label=service=app --filter label=destination= --filter label=role=web-rollout", output
      assert_match "docker container prune --force --filter label=service=app --filter label=destination= --filter label=role=workers-rollout", output
    end
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
      assert_no_match "kamal-proxy rollout stop", output
    end
  end

  test "deploy stops a live rollout when told to" do
    stub_deploy_invocations

    run_deploy("--rollout", "stop").tap do |output|
      assert_match "Rollout still live (web at 1234, workers at 1234). Stopping the split.", output
      assert_match "docker exec kamal-proxy kamal-proxy rollout stop app-web", output
    end
  end

  test "deploy says nothing when no rollout is running" do
    stub_deploy_invocations
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("")

    run_deploy.tap do |output|
      assert_no_match "Rollout still live", output
    end
  end

  test "deploy rejects an unknown rollout behaviour" do
    assert_raises(Kamal::Cli::RolloutError) { run_deploy("--rollout", "bogus") }
  end

  private
    def stub_deploy_invocations
      Kamal::Cli::Main.any_instance.stubs(:invoke)
      Kamal::Cli::Main.any_instance.stubs(:run_hook)
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("1234")
    end

    def run_deploy(*extra)
      with_argv([ "deploy", "-P", *extra, "-c", "test/fixtures/deploy_with_rollout.yml" ]) do
        stdouted { Kamal::Cli::Main.start }
      end
    end

    def stub_rollout_booting
      Object.any_instance.stubs(:sleep)

      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("running")
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
        .with { |*args, **kwargs| kwargs[:raise_on_non_zero_exit] == false }
        .returns("")
    end

    def run_command(*command, fixture: :with_rollout)
      stdouted { Kamal::Cli::Rollout.start([ *command, "-c", "test/fixtures/deploy_#{fixture}.yml" ]) }
    end
end
