require "test_helper"
require "mrsk/configuration"
require "mrsk/commands/image"

class CommandsImageTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "azolf/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ] }
    @image = Mrsk::Commands::Image.new Mrsk::Configuration.new(@config)
  end

  test "image list without filter" do
    assert_equal \
    [:docker, :images, "azolf/app", ""], @image.list
  end

  test "image list with format" do
    format = "{{.ID}}"
    assert_equal \
    [:docker, :images, "azolf/app", "--format={{.ID}}"], @image.list(format)
  end

  test "remove images" do
    ids = ['123', '456']

    assert_equal \
    [:docker, :rmi, '123 456'], @image.rm(ids)
  end
end