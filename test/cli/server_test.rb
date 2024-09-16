require_relative "cli_test_case"

class CliServerTest < CliTestCase
  test "running a command with exec" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with("date", verbosity: 1)
      .returns("Today")

    hosts = "1.1.1.1".."1.1.1.4"
    run_command("exec", "date").tap do |output|
      hosts.map do |host|
        assert_match "Running 'date' on #{hosts.to_a.join(', ')}...", output
        assert_match "App Host: #{host}\nToday", output
      end
    end
  end

  test "running a command with exec multiple arguments" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with("date -j", verbosity: 1)
      .returns("Today")

    hosts = "1.1.1.1".."1.1.1.4"
    run_command("exec", "date", "-j").tap do |output|
      hosts.map do |host|
        assert_match "Running 'date -j' on #{hosts.to_a.join(', ')}...", output
        assert_match "App Host: #{host}\nToday", output
      end
    end
  end

  test "bootstrap already installed" do
    stub_setup
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:docker, "-v", raise_on_non_zero_exit: false).returns(true).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:mkdir, "-p", ".kamal").returns("").at_least_once

    assert_equal "Acquiring the deploy lock...\nReleasing the deploy lock...", run_command("bootstrap")
  end

  test "bootstrap install as non-root user" do
    stub_setup
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:docker, "-v", raise_on_non_zero_exit: false).returns(false).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with('[ "${EUID:-$(id -u)}" -eq 0 ] || command -v sudo >/dev/null || command -v su >/dev/null', raise_on_non_zero_exit: false).returns(false).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:mkdir, "-p", ".kamal").returns("").at_least_once

    assert_raise RuntimeError, "Docker is not installed on 1.1.1.1, 1.1.1.3, 1.1.1.4, 1.1.1.2 and can't be automatically installed without having root access and the `curl` command available. Install Docker manually: https://docs.docker.com/engine/install/" do
      run_command("bootstrap")
    end
  end

  test "bootstrap install as root user" do
    stub_setup
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:docker, "-v", raise_on_non_zero_exit: false).returns(false).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with('[ "${EUID:-$(id -u)}" -eq 0 ] || command -v sudo >/dev/null || command -v su >/dev/null', raise_on_non_zero_exit: false).returns(true).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:sh, "-c", "'curl -fsSL https://get.docker.com || wget -O - https://get.docker.com || echo \"exit 1\"'", "|", :sh).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:mkdir, "-p", ".kamal").returns("").at_least_once
    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(".kamal/hooks/pre-connect", anything).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(".kamal/hooks/docker-setup", anything).at_least_once

    run_command("bootstrap").tap do |output|
      ("1.1.1.1".."1.1.1.4").map do |host|
        assert_match "Missing Docker on #{host}. Installing…", output
        assert_match "Running the docker-setup hook", output
      end
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Server.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
