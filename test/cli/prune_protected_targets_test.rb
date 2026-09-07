require_relative "cli_test_case"

class PruneProtectedTargetsTest < CliTestCase
  test "protects sleeping active and rollout targets" do
    stub_list({ "app-web" => { "targets" => [ "abc123:80" ], "read_targets" => [], "rollout" => { "targets" => [ "def456:80" ], "read_targets" => [] } } }.to_json)
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with(:docker, :inspect, "--format", "'{{.Id}}'", "abc123", "def456").returns("#{'a' * 64}\n#{'b' * 64}\n")
    output = run_prune
    assert_includes output, "#{'a' * 64}"
    assert_includes output, "#{'b' * 64}"
    assert_includes output, "--no-trunc"
  end

  test "malformed JSON skips container deletion" do
    stub_list("not json")
    assert_skipped
  end

  test "missing service skips container deletion" do
    stub_list("{}")
    assert_skipped
  end

  test "empty targets skip container deletion" do
    stub_list({ "app-web" => { "targets" => [] } }.to_json)
    assert_skipped
  end

  test "proxy command failure skips container deletion" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with(:docker, :exec, "kamal-proxy", "kamal-proxy", :list, "--json").raises(SSHKit::Command::Failed, "proxy unavailable")
    assert_skipped
  end

  test "invalid target cannot reach the shell" do
    stub_list({ "app-web" => { "targets" => [ "$(touch /tmp/unsafe):80" ] } }.to_json)
    assert_skipped
  end

  test "inspect failure skips container deletion" do
    stub_list({ "app-web" => { "targets" => [ "abc123:80" ] } }.to_json)
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with(:docker, :inspect, "--format", "'{{.Id}}'", "abc123").raises(SSHKit::Command::Failed, "missing container")
    assert_skipped
  end

  test "incomplete inspection skips container deletion" do
    stub_list({ "app-web" => { "targets" => [ "abc123:80" ] } }.to_json)
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with(:docker, :inspect, "--format", "'{{.Id}}'", "abc123").returns("")
    assert_skipped
  end

  test "worker-only prune still protects a sleeping sibling web role" do
    stub_list({ "app-web" => { "targets" => [ "abc123:80" ] } }.to_json)
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with(:docker, :inspect, "--format", "'{{.Id}}'", "abc123").returns("#{'a' * 64}\n")
    assert_includes run_prune("--roles", "workers"), "#{'a' * 64}"
  end

  test "host without proxied roles does not need the proxy" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info).with(:docker, :exec, "kamal-proxy", "kamal-proxy", :list, "--json").never
    output = stdouted { Kamal::Cli::Prune.start([ "containers", "-c", "test/fixtures/deploy_with_idle_prune.yml", "--hosts", "1.1.1.2" ]) }
    assert_includes output, "docker rm"
  end

  private
    def stub_list(json)
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with(:docker, :exec, "kamal-proxy", "kamal-proxy", :list, "--json").returns(json)
    end

    def run_prune(*args)
      stdouted { Kamal::Cli::Prune.start([ "containers", "-c", "test/fixtures/deploy_with_idle_prune.yml", "--hosts", "1.1.1.1", *args ]) }
    end

    def assert_skipped
      output = run_prune
      assert_includes output, "Skipping container prune"
      assert_not_includes output, "docker rm"
    end
end
