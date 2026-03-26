require "test_helper"

class CommandsDockerTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ], builder: { "arch" => "amd64" }
    }
    @docker = Kamal::Commands::Docker.new(Kamal::Configuration.new(@config))
  end

  test "install" do
    assert_equal "sh -c 'curl -fsSL https://get.docker.com || wget -O - https://get.docker.com || echo \"exit 1\"' | sh", @docker.install.join(" ")
  end

  test "installed?" do
    assert_equal "docker -v", @docker.installed?.join(" ")
  end

  test "running?" do
    assert_equal "docker version", @docker.running?.join(" ")
  end

  test "superuser?" do
    assert_equal '[ "${EUID:-$(id -u)}" -eq 0 ] || sudo -nl usermod >/dev/null', @docker.superuser?.join(" ")
  end

  test "root?" do
    assert_equal '[ "${EUID:-$(id -u)}" -eq 0 ]', @docker.root?.join(" ")
  end

  test "in_docker_group?" do
    assert_equal 'id -nG "${USER:-$(id -un)}" | grep -qw docker', @docker.in_docker_group?.join(" ")
  end

  test "add_to_docker_group" do
    assert_equal 'sudo -n usermod -aG docker "${USER:-$(id -un)}"', @docker.add_to_docker_group.join(" ")
  end

  test "refresh_session" do
    assert_equal "kill -HUP $PPID", @docker.refresh_session.join(" ")
  end
end
