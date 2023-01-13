require "test_helper"
require "mrsk/configuration"
require "mrsk/commands/builder"

class BuilderCommandTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ] }
  end

  test "target multiarch by default" do
    builder = Mrsk::Commands::Builder.new(Mrsk::Configuration.new(@config))
    assert builder.multiarch?
  end

  test "target native when multiarch is off" do
    builder = Mrsk::Commands::Builder.new(Mrsk::Configuration.new(@config.merge({ builder: { "multiarch" => false } })))
    assert builder.native?
  end

  test "target multiarch remote when local and remote is set" do
    builder = Mrsk::Commands::Builder.new(Mrsk::Configuration.new(@config.merge({ builder: { "local" => { }, "remote" => { } } })))
    assert builder.remote?
  end
end
