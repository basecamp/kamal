require "test_helper"

class CommanderTest < ActiveSupport::TestCase
  setup do
    @mrsk = Mrsk::Commander.new.tap do |mrsk|
      mrsk.configure config_file: Pathname.new(File.expand_path("fixtures/deploy_with_roles.yml", __dir__))
    end
  end

  test "lazy configuration" do
    assert_equal Mrsk::Configuration, @mrsk.config.class
  end

  test "overwriting hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.specific_hosts = [ "1.2.3.4", "1.2.3.5" ]
    assert_equal [ "1.2.3.4", "1.2.3.5" ], @mrsk.hosts
  end

  test "overwriting hosts with roles" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.specific_roles = [ "workers", "web" ]
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.specific_roles = [ "workers" ]
    assert_equal [ "1.1.1.3", "1.1.1.4" ], @mrsk.hosts
  end

  test "overwriting hosts with primary" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.specific_primary!
    assert_equal [ "1.1.1.1" ], @mrsk.hosts
  end

  test "primary_host with specific hosts via role" do
    @mrsk.specific_roles = "web"
    assert_equal "1.1.1.1", @mrsk.primary_host
  end
end
