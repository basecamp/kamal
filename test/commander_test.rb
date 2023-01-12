require "test_helper"
require "mrsk/commander"

class CommanderTest < ActiveSupport::TestCase
  setup do
    @mrsk = Mrsk::Commander.new config_file: Pathname.new(File.expand_path("fixtures/deploy.erb.yml", __dir__))
  end

  test "lazy configuration" do
    assert_equal Mrsk::Configuration, @mrsk.config.class
  end
end
