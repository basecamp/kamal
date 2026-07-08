require "test_helper"

class CommandsBaseTest < ActiveSupport::TestCase
  setup do
    @config_hash = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1" ], builder: { "arch" => "amd64" }
    }
  end

  test "docker seam defaults to the docker binary" do
    assert_equal [ :docker, :ps ], base.send(:docker, :ps)
  end

  test "docker seam switches to podman when configured" do
    assert_equal [ :podman, :ps ], base(container_engine: "podman").send(:docker, :ps)
  end

  # Guards the divergence claim: every command routes through the seam, so a full
  # built command flips its binary end to end with a single config value.
  test "engine swap threads through a fully built command" do
    assert_match(/\Adocker run /, app.run.join(" "))
    assert_match(/\Apodman run /, app(container_engine: "podman").run.join(" "))
  end

  test "ensure_docker_installed skips the buildx check under podman" do
    assert_equal "docker --version && docker buildx version", base.ensure_docker_installed.join(" ")
    assert_equal "podman --version", base(container_engine: "podman").ensure_docker_installed.join(" ")
  end

  private
    def base(**extra)
      Kamal::Commands::Base.new(config(**extra))
    end

    def app(**extra)
      config = config(**extra)
      Kamal::Commands::App.new(config, role: config.role("web"), host: "1.1.1.1")
    end

    def config(**extra)
      Kamal::Configuration.new(@config_hash.merge(extra), version: "999")
    end
end
