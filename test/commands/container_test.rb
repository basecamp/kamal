require "test_helper"
require "mrsk/configuration"
require "mrsk/commands/container"

class CommandsContainerTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "azolf/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ] }
    @container = Mrsk::Commands::Container.new Mrsk::Configuration.new(@config)
  end

  test "container list" do
    assert_equal \
    [:docker, :ps, "--all", "", "--filter", "label=service=app", "", ""], @container.list
  end

  test "container list with format" do
    format = "{{.ID}}"

    assert_equal \
    [:docker, :ps, "--all", "--format={{.ID}}", "--filter", "label=service=app", "", ""], @container.list(format: format)
  end

  test "container list with filter" do
    filter = "status=exited"

    assert_equal \
    [:docker, :ps, "--all", "", "--filter", "label=service=app", "", "--filter=status=exited"], @container.list(filter: filter)
  end

  test "container list last 5" do
    assert_equal \
    [:docker, :ps, "--all", "", "--filter", "label=service=app", "--last 5", ""], @container.list(last: 5)
  end

  test "remove containers" do
    ids = ['123', '456']

    assert_equal \
    [:docker, :rm, '123 456'], @container.rm(ids)
  end
end