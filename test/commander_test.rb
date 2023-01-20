require "test_helper"
require "mrsk/commander"

class CommanderTest < ActiveSupport::TestCase
  setup do
    @mrsk = Mrsk::Commander.new config_file: Pathname.new(File.expand_path("fixtures/deploy_with_roles.yml", __dir__))
  end

  test "lazy configuration" do
    assert_equal Mrsk::Configuration, @mrsk.config.class
  end

  test "overwriting hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.hosts = [ "1.2.3.4", "1.2.3.5" ]
    assert_equal [ "1.2.3.4", "1.2.3.5" ], @mrsk.hosts
  end

  test "overwriting hosts with roles" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.roles = [ "workers", "web" ]
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @mrsk.hosts

    @mrsk.roles = [ "workers" ]
    assert_equal [ "1.1.1.3", "1.1.1.4" ], @mrsk.hosts
  end
end
