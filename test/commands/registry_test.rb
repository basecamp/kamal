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
    @registry = Mrsk::Commands::Registry.new Mrsk::Configuration.new(@config)
  end

  test "registry login" do
    assert_equal [ :docker, :login, "hub.docker.com", "-u", "dhh", "-p", "secret" ], @registry.login
  end

  test "registry logout" do
    assert_equal [:docker, :logout, "hub.docker.com"], @registry.logout
  end
end
