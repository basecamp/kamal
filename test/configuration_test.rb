require "test_helper"
require "mrsk/configuration"

ENV["VERSION"] = "123"

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" } }
  end

  test "absolute image" do
    configuration = Mrsk::Configuration.new(@config)
    assert_equal "dhh/app:123", configuration.absolute_image

    configuration = Mrsk::Configuration.new(@config.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app:123", configuration.absolute_image
  end
end
