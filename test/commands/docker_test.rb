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
    assert_equal '[ "${EUID:-$(id -u)}" -eq 0 ] || command -v sudo >/dev/null || command -v su >/dev/null', @docker.superuser?.join(" ")
  end
end
