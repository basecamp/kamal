require "test_helper"

class ConfigurationBootTest < ActiveSupport::TestCase
  test "no boot config" do
    config = config_with_boot(nil)

    assert_nil config.boot.limit
    assert_nil config.boot.wait
    assert_nil config.boot.parallel_roles
    assert_empty config.boot.role_order
  end

  test "specific limit group strategy" do
    config = config_with_boot("limit" => 3, "wait" => 2)

    assert_equal 3, config.boot.limit
    assert_equal 2, config.boot.wait
  end

  test "percentage-based group strategy" do
    config = config_with_boot("limit" => "50%", "wait" => 2)

    assert_equal 2, config.boot.limit
    assert_equal 2, config.boot.wait
  end

  test "percentage-based group strategy limit is at least 1" do
    config = config_with_boot("limit" => "1%", "wait" => 2)

    assert_equal 1, config.boot.limit
    assert_equal 2, config.boot.wait
  end

  test "parallel_roles" do
    config = config_with_boot("parallel_roles" => true)

    assert_equal true, config.boot.parallel_roles
  end

  test "role_order" do
    config = config_with_boot("role_order" => [ "workers", "web" ])

    assert_equal [ "workers", "web" ], config.boot.role_order
    assert_equal [ "web", "workers", "cron" ], config.boot.ordered_roles(config.roles, primary_role: config.primary_role).map(&:name)
  end

  test "role_order rejects duplicate roles" do
    error = assert_raises(Kamal::ConfigurationError) do
      config_with_boot("role_order" => [ "workers", "workers" ])
    end

    assert_equal "Duplicate roles in boot.role_order: workers", error.message
  end

  test "role_order rejects unknown roles" do
    error = assert_raises(Kamal::ConfigurationError) do
      config_with_boot("role_order" => [ "missing" ])
    end

    assert_equal "Unknown roles in boot.role_order: missing", error.message
  end

  private
    def config_with_boot(boot)
      deploy = {
        service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, builder: { "arch" => "amd64" },
        servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "cron" => [ "1.1.1.1" ], "workers" => [ "1.1.1.3", "1.1.1.4" ] },
        boot: boot
      }.compact

      Kamal::Configuration.new(deploy)
    end
end
