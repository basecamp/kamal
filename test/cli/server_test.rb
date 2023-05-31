require_relative "cli_test_case"

class CliServerTest < CliTestCase
  test "bootstrap already installed" do
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:docker, "-v", raise_on_non_zero_exit: false).returns(true).at_least_once

    assert_equal "", run_command("bootstrap")
  end

  test "bootstrap install as non-root user" do
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:docker, "-v", raise_on_non_zero_exit: false).returns(false).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with('[ "${EUID:-$(id -u)}" -eq 0 ]', raise_on_non_zero_exit: false).returns(false).at_least_once

    assert_raise RuntimeError, "Docker is not installed on 1.1.1.1, 1.1.1.3, 1.1.1.4, 1.1.1.2 and can't be automatically installed without having root access and the `curl` command available. Install Docker manually: https://docs.docker.com/engine/install/" do
      run_command("bootstrap")
    end
  end

  test "bootstrap install as root user" do
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:docker, "-v", raise_on_non_zero_exit: false).returns(false).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with('[ "${EUID:-$(id -u)}" -eq 0 ]', raise_on_non_zero_exit: false).returns(true).at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:execute).with(:curl, "-fsSL", "https://get.docker.com", "|", :sh).at_least_once

    run_command("bootstrap").tap do |output|
      ("1.1.1.1".."1.1.1.4").map do |host|
        assert_match "Missing Docker on #{host}. Installing…", output
      end
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Server.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
