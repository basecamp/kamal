require "test_helper"

class PortForwardingTest < ActiveSupport::TestCase
  test "forwards the local registry port over the OS ssh client" do
    command = ssh_command(user: "root", port: 22)

    assert_equal "ssh", command.first
    assert_includes_sequence command, [ "-R", "127.0.0.1:5000:localhost:5000" ]
    assert_equal "root@1.1.1.1", command[-2]
  end

  test "does not pass -N so the readiness command runs" do
    # -N tells ssh not to execute a remote command, which would prevent the
    # READY handshake from ever firing and hang every deploy.
    command = ssh_command(user: "root", port: 22)

    assert_not_includes command, "-N"
    assert_includes_sequence command, [ "-o", "ExitOnForwardFailure=yes" ]
    assert_match(/\Aecho \S+ && exec cat\z/, command.last)
  end

  test "maps ssh options to ssh flags" do
    command = ssh_command(
      user: "app", port: 2222, keys: [ "/k1", "/k2" ], keys_only: true,
      config: "/my/ssh_config", forward_agent: true, keepalive_interval: 45
    )

    assert_equal "app@1.1.1.1", command[-2]
    assert_includes_sequence command, [ "-p", "2222" ]
    assert_includes_sequence command, [ "-i", "/k1" ]
    assert_includes_sequence command, [ "-i", "/k2" ]
    assert_includes_sequence command, [ "-o", "IdentitiesOnly=yes" ]
    assert_includes_sequence command, [ "-o", "ForwardAgent=yes" ]
    assert_includes_sequence command, [ "-F", "/my/ssh_config" ]
    assert_includes_sequence command, [ "-o", "ServerAliveInterval=45" ]
  end

  test "maps a jump proxy to -J" do
    command = ssh_command(proxy: Net::SSH::Proxy::Jump.new("root@bastion"))

    assert_includes_sequence command, [ "-J", "root@bastion" ]
  end

  test "maps a proxy command to ProxyCommand" do
    command = ssh_command(proxy: Net::SSH::Proxy::Command.new("connect -S relay %h %p"))

    assert_includes_sequence command, [ "-o", "ProxyCommand=connect -S relay %h %p" ]
  end

  private
    def ssh_command(**ssh_options)
      Kamal::Cli::Build::PortForwarding.new([ "1.1.1.1" ], 5000, **ssh_options).send(:ssh_command, "1.1.1.1")
    end

    def assert_includes_sequence(array, subarray)
      found = array.each_cons(subarray.size).include?(subarray)
      assert found, "expected #{array.inspect}\nto contain consecutive #{subarray.inspect}"
    end
end
