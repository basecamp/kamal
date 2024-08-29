require "test_helper"

class CommandsRegistryTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app",
      image: "dhh/app",
      registry: { "username" => "dhh",
        "password" => "secret",
        "server" => "hub.docker.com"
      },
      servers: [ "1.1.1.1" ]
    }
    @registry = Kamal::Commands::Registry.new Kamal::Configuration.new(@config)
  end

  test "registry login" do
    assert_equal \
      "docker login hub.docker.com -u \"dhh\" -p \"secret\"",
      @registry.login.join(" ")
  end

  test "registry login with ENV password" do
    ENV["KAMAL_REGISTRY_PASSWORD"] = "more-secret"
    @config[:registry]["password"] = [ "KAMAL_REGISTRY_PASSWORD" ]

    assert_equal \
      "docker login hub.docker.com -u \"dhh\" -p \"more-secret\"",
      @registry.login.join(" ")
  ensure
    ENV.delete("KAMAL_REGISTRY_PASSWORD")
  end

  test "registry login escape password" do
    ENV["KAMAL_REGISTRY_PASSWORD"] = "more-secret'\""
    @config[:registry]["password"] = [ "KAMAL_REGISTRY_PASSWORD" ]

    assert_equal \
      "docker login hub.docker.com -u \"dhh\" -p \"more-secret'\\\"\"",
      @registry.login.join(" ")
  ensure
    ENV.delete("KAMAL_REGISTRY_PASSWORD")
  end

  test "registry login with ENV username" do
    ENV["KAMAL_REGISTRY_USERNAME"] = "also-secret"
    @config[:registry]["username"] = [ "KAMAL_REGISTRY_USERNAME" ]

    assert_equal \
      "docker login hub.docker.com -u \"also-secret\" -p \"secret\"",
      @registry.login.join(" ")
  ensure
    ENV.delete("KAMAL_REGISTRY_USERNAME")
  end

  test "registry logout" do
    assert_equal \
      "docker logout hub.docker.com",
      @registry.logout.join(" ")
  end
end
