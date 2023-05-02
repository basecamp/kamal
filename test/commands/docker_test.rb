require "test_helper"

class CommandsDockerTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ]
    }
    @docker = Mrsk::Commands::Docker.new(Mrsk::Configuration.new(@config))
  end

  test "install" do
    assert_equal "curl -fsSL https://get.docker.com | sh", @docker.install.join(" ")
  end

  test "installed?" do
    assert_equal "docker -v", @docker.installed?.join(" ")
  end

  test "running?" do
    assert_equal "docker version", @docker.running?.join(" ")
  end

  test "superuser?" do
    assert_equal '[ "${EUID:-$(id -u)}" -eq 0 ]', @docker.superuser?.join(" ")
  end
end
