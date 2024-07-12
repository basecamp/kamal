require "test_helper"

class CommanderTest < ActiveSupport::TestCase
  setup do
    configure_with(:deploy_with_roles)
  end

  test "lazy configuration" do
    assert_equal Kamal::Configuration, @kamal.config.class
  end

  test "overwriting hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @kamal.hosts

    @kamal.specific_hosts = [ "1.1.1.1", "1.1.1.2" ]
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @kamal.hosts

    @kamal.specific_hosts = [ "1.1.1.1*" ]
    assert_equal [ "1.1.1.1" ], @kamal.hosts

    @kamal.specific_hosts = [ "1.1.1.*", "*.1.2.*" ]
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @kamal.hosts

    @kamal.specific_hosts = [ "*" ]
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @kamal.hosts

    @kamal.specific_hosts = [ "1.1.1.[12]" ]
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @kamal.hosts

    exception = assert_raises(ArgumentError) do
      @kamal.specific_hosts = [ "*miss" ]
    end
    assert_match /hosts match for \*miss/, exception.message
  end

  test "filtering hosts by filtering roles" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @kamal.hosts

    @kamal.specific_roles = [ "web" ]
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @kamal.hosts

    exception = assert_raises(ArgumentError) do
      @kamal.specific_roles = [ "*miss" ]
    end
    assert_match /roles match for \*miss/, exception.message
  end

  test "filtering roles" do
    assert_equal [ "web", "workers" ], @kamal.roles.map(&:name)

    @kamal.specific_roles = [ "workers" ]
    assert_equal [ "workers" ], @kamal.roles.map(&:name)

    @kamal.specific_roles = [ "w*" ]
    assert_equal [ "web", "workers" ], @kamal.roles.map(&:name)

    @kamal.specific_roles = [ "we*", "*orkers" ]
    assert_equal [ "web", "workers" ], @kamal.roles.map(&:name)

    @kamal.specific_roles = [ "*" ]
    assert_equal [ "web", "workers" ], @kamal.roles.map(&:name)

    @kamal.specific_roles = [ "w{eb,orkers}" ]
    assert_equal [ "web", "workers" ], @kamal.roles.map(&:name)

    exception = assert_raises(ArgumentError) do
      @kamal.specific_roles = [ "*miss" ]
    end
    assert_match /roles match for \*miss/, exception.message
  end

  test "filtering roles by filtering hosts" do
    assert_equal [ "web", "workers" ], @kamal.roles.map(&:name)

    @kamal.specific_hosts = [ "1.1.1.3" ]
    assert_equal [ "workers" ], @kamal.roles.map(&:name)
  end

  test "overwriting hosts with primary" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @kamal.hosts

    @kamal.specific_primary!
    assert_equal [ "1.1.1.1" ], @kamal.hosts
  end

  test "primary_host with specific hosts via role" do
    @kamal.specific_roles = "workers"
    assert_equal "1.1.1.3", @kamal.primary_host
  end

  test "primary_role" do
    assert_equal "web", @kamal.primary_role.name
    @kamal.specific_roles = "workers"
    assert_equal "workers", @kamal.primary_role.name
  end

  test "roles_on" do
    assert_equal [ "web" ], @kamal.roles_on("1.1.1.1").map(&:name)
    assert_equal [ "workers" ], @kamal.roles_on("1.1.1.3").map(&:name)
  end

  test "roles_on web comes first" do
    configure_with(:deploy_with_two_roles_one_host)
    assert_equal [ "web", "workers" ], @kamal.roles_on("1.1.1.1").map(&:name)
  end

  test "default group strategy" do
    assert_empty @kamal.boot_strategy
  end

  test "specific limit group strategy" do
    configure_with(:deploy_with_boot_strategy)

    assert_equal({ in: :groups, limit: 3, wait: 2 }, @kamal.boot_strategy)
  end

  test "percentage-based group strategy" do
    configure_with(:deploy_with_percentage_boot_strategy)

    assert_equal({ in: :groups, limit: 1, wait: 2 }, @kamal.boot_strategy)
  end

  test "percentage-based group strategy limit is at least 1" do
    configure_with(:deploy_with_low_percentage_boot_strategy)

    assert_equal({ in: :groups, limit: 1, wait: 2 }, @kamal.boot_strategy)
  end

  test "try to match the primary role from a list of specific roles" do
    configure_with(:deploy_primary_web_role_override)

    @kamal.specific_roles = [ "web_*" ]
    assert_equal [ "web_tokyo", "web_chicago" ], @kamal.roles.map(&:name)
    assert_equal "web_tokyo", @kamal.primary_role.name
    assert_equal "1.1.1.3", @kamal.primary_host
    assert_equal [ "1.1.1.3", "1.1.1.4", "1.1.1.1", "1.1.1.2" ], @kamal.hosts
  end

  test "traefik hosts should observe filtered roles" do
    configure_with(:deploy_with_multiple_traefik_roles)

    @kamal.specific_roles = [ "web_tokyo" ]
    assert_equal [ "1.1.1.3", "1.1.1.4" ], @kamal.traefik_hosts
  end

  test "traefik hosts should observe filtered hosts" do
    configure_with(:deploy_with_multiple_traefik_roles)

    @kamal.specific_hosts = [ "1.1.1.2" ]
    assert_equal [ "1.1.1.2" ], @kamal.traefik_hosts
  end

  private
    def configure_with(variant)
      @kamal = Kamal::Commander.new.tap do |kamal|
        kamal.configure config_file: Pathname.new(File.expand_path("fixtures/#{variant}.yml", __dir__))
      end
    end
end
