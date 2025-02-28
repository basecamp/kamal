require "test_helper"

class ConfigurationBootTest < ActiveSupport::TestCase
  test "no group strategy" do
    deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, builder: { "arch" => "amd64" },
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "workers" => [ "1.1.1.3", "1.1.1.4" ] }
    }

    config = Kamal::Configuration.new(deploy)

    assert_nil config.boot.limit
    assert_nil config.boot.wait
  end

  test "specific limit group strategy" do
    deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, builder: { "arch" => "amd64" },
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "workers" => [ "1.1.1.3", "1.1.1.4" ] },
      boot: { "limit" => 3, "wait" => 2 }
    }

    config = Kamal::Configuration.new(deploy)

    assert_equal 3, config.boot.limit
    assert_equal 2, config.boot.wait
  end

  test "percentage-based group strategy" do
    deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, builder: { "arch" => "amd64" },
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "workers" => [ "1.1.1.3", "1.1.1.4" ] },
      boot: { "limit" => "50%", "wait" => 2 }
    }

    config = Kamal::Configuration.new(deploy)

    assert_equal 2, config.boot.limit
    assert_equal 2, config.boot.wait
  end

  test "percentage-based group strategy limit is at least 1" do
    deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, builder: { "arch" => "amd64" },
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "workers" => [ "1.1.1.3", "1.1.1.4" ] },
      boot: { "limit" => "1%", "wait" => 2 }
    }

    config = Kamal::Configuration.new(deploy)

    assert_equal 1, config.boot.limit
    assert_equal 2, config.boot.wait
  end
end
