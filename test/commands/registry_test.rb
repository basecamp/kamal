require "test_helper"

class CommandsRegistryTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app",
      image: "dhh/app",
      registry: {
        "username" => "dhh",
        "password" => "secret",
        "server" => "hub.docker.com"
      },
      builder: { "arch" => "amd64" },
      servers: [ "1.1.1.1" ],
      accessories: {
        "db" => {
          "image" => "mysql:8.0",
          "hosts" => [ "1.1.1.1" ],
          "registry" => {
            "username" => "user",
            "password" => "pw",
            "server" => "other.hub.docker.com"
          }
        }
      }
    }
  end

  test "registry login" do
    assert_equal \
      "docker login hub.docker.com -u \"dhh\" -p \"secret\"",
      registry.login.join(" ")
  end

  test "given registry login" do
    assert_equal \
      "docker login other.hub.docker.com -u \"user\" -p \"pw\"",
      registry.login(registry_config: accessory_registry_config).join(" ")
  end

  test "registry login with ENV password" do
    with_test_secrets("secrets" => "KAMAL_REGISTRY_PASSWORD=more-secret\nKAMAL_MYSQL_REGISTRY_PASSWORD=secret-pw") do
      @config[:registry]["password"] = [ "KAMAL_REGISTRY_PASSWORD" ]
      @config[:accessories]["db"]["registry"]["password"] = [ "KAMAL_MYSQL_REGISTRY_PASSWORD" ]

      assert_equal \
        "docker login hub.docker.com -u \"dhh\" -p \"more-secret\"",
        registry.login.join(" ")

      assert_equal \
        "docker login other.hub.docker.com -u \"user\" -p \"secret-pw\"",
        registry.login(registry_config: accessory_registry_config).join(" ")
    end
  end

  test "registry login escape password" do
    with_test_secrets("secrets" => "KAMAL_REGISTRY_PASSWORD=more-secret'\"") do
      @config[:registry]["password"] = [ "KAMAL_REGISTRY_PASSWORD" ]

      assert_equal \
        "docker login hub.docker.com -u \"dhh\" -p \"more-secret'\\\"\"",
        registry.login.join(" ")
    end
  end

  test "registry login with ENV username" do
    with_test_secrets("secrets" => "KAMAL_REGISTRY_USERNAME=also-secret") do
      @config[:registry]["username"] = [ "KAMAL_REGISTRY_USERNAME" ]

      assert_equal \
        "docker login hub.docker.com -u \"also-secret\" -p \"secret\"",
        registry.login.join(" ")
    end
  end

  test "registry logout" do
    assert_equal \
      "docker logout hub.docker.com",
      registry.logout.join(" ")
  end

  test "apple container local registry login and logout" do
    assert_equal \
      "echo \"secret\" | container registry login --username \"dhh\" --password-stdin hub.docker.com",
      apple_registry.login.join(" ")
    assert_equal "container registry logout hub.docker.com", apple_registry.logout.join(" ")
    assert_equal "docker login hub.docker.com -u \"dhh\" -p \"secret\"", registry.login.join(" ")
  end

  test "apple container registry login uses its configured scheme" do
    @config[:registry]["scheme"] = "http"

    assert_equal \
      "echo \"secret\" | container registry login --scheme http --username \"dhh\" --password-stdin hub.docker.com",
      apple_registry.login.join(" ")
  end

  test "apple container registry login leaves the scheme to container when set to auto" do
    @config[:registry]["scheme"] = "auto"

    assert_equal \
      "echo \"secret\" | container registry login --username \"dhh\" --password-stdin hub.docker.com",
      apple_registry.login.join(" ")
  end

  test "given registry logout" do
    assert_equal \
      "docker logout other.hub.docker.com",
      registry.logout(registry_config: accessory_registry_config).join(" ")
  end

  test "registry setup" do
    @config[:registry] = { "server" => "localhost:5000" }
    assert_equal "docker start kamal-docker-registry || docker run --detach -p 127.0.0.1:5000:5000 --name kamal-docker-registry registry:3", registry.setup.join(" ")
  end

  test "registry remove" do
    assert_equal "docker stop kamal-docker-registry && docker rm kamal-docker-registry", registry.remove.join(" ")
  end

  test "apple container local registry setup and remove" do
    @config[:registry] = { "server" => "localhost:5000" }

    assert_equal \
      "container start kamal-docker-registry || container run --detach -p 127.0.0.1:5000:5000 --name kamal-docker-registry registry:3",
      apple_registry.setup.join(" ")
    assert_equal \
      "container stop kamal-docker-registry && container delete kamal-docker-registry",
      apple_registry.remove.join(" ")
  end

  test "both engines manage the same local registry container" do
    @config[:registry] = { "server" => "localhost:5000" }

    assert_equal registry.setup.join(" ").gsub("docker ", ""),
      apple_registry.setup.join(" ").gsub("container ", "")
  end

  private
    def registry
      Kamal::Commands::Registry.new main_config
    end

    def apple_registry
      Kamal::Commands::Registry::AppleContainer.new main_config
    end

    def main_config
      Kamal::Configuration.new(@config)
    end

    def accessory_registry_config
      main_config.accessory("db").registry
    end
end
