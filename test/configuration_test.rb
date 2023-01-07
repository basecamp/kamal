require "test_helper"
require "mrsk/configuration"

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" } }
  end

  test "absolute image" do
    configuration = Mrsk::Configuration.new(@config)
    assert_equal "dhh/app", configuration.absolute_image

    configuration = Mrsk::Configuration.new(@config.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app", configuration.absolute_image
  end
end
