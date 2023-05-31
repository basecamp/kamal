require "test_helper"

class CommanderTest < ActiveSupport::TestCase
  setup do
    configure_with(:deploy_with_roles)
  end

  test "lazy configuration" do
    assert_equal Mrsk::Configuration, @mrsk.config.class
  end

  test "overwriting hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.specific_hosts = [ "1.1.1.1", "1.1.1.2" ]
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @mrsk.hosts
  end

  test "filtering hosts by filtering roles" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.specific_roles = [ "web" ]
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @mrsk.hosts
  end

  test "filtering roles" do
    assert_equal [ "web", "workers" ], @mrsk.roles.map(&:name)

    @mrsk.specific_roles = [ "workers" ]
    assert_equal [ "workers" ], @mrsk.roles.map(&:name)
  end

  test "filtering roles by filtering hosts" do
    assert_equal [ "web", "workers" ], @mrsk.roles.map(&:name)

    @mrsk.specific_hosts = [ "1.1.1.3" ]
    assert_equal [ "workers" ], @mrsk.roles.map(&:name)
  end

  test "overwriting hosts with primary" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.specific_primary!
    assert_equal [ "1.1.1.1" ], @mrsk.hosts
  end

  test "primary_host with specific hosts via role" do
    @mrsk.specific_roles = "workers"
    assert_equal "1.1.1.3", @mrsk.primary_host
  end

  test "roles_on" do
    assert_equal [ "web" ], @mrsk.roles_on("1.1.1.1")
    assert_equal [ "workers" ], @mrsk.roles_on("1.1.1.3")
  end

  test "default group strategy" do
    assert_empty @mrsk.boot_strategy
  end

  test "specific limit group strategy" do
    configure_with(:deploy_with_boot_strategy)

    assert_equal({ in: :groups, limit: 3, wait: 2 }, @mrsk.boot_strategy)
  end

  test "percentage-based group strategy" do
    configure_with(:deploy_with_percentage_boot_strategy)

    assert_equal({ in: :groups, limit: 1, wait: 2 }, @mrsk.boot_strategy)
  end

  private
    def configure_with(variant)
      @mrsk = Mrsk::Commander.new.tap do |mrsk|
        mrsk.configure config_file: Pathname.new(File.expand_path("fixtures/#{variant}.yml", __dir__))
      end
    end
end
