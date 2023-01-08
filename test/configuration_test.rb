require "test_helper"
require "mrsk/configuration"

ENV["VERSION"] = "123"

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" } }
  end

  test "ensure valid keys" do
    assert_raise(ArgumentError) do
      Mrsk::Configuration.new(@config.tap { _1.delete(:service) })
      Mrsk::Configuration.new(@config.tap { _1.delete(:image) })
      Mrsk::Configuration.new(@config.tap { _1.delete(:registry) })

      Mrsk::Configuration.new(@config.tap { _1[:registry].delete("username") })
      Mrsk::Configuration.new(@config.tap { _1[:registry].delete("password") })
    end
  end

  test "repository" do
    configuration = Mrsk::Configuration.new(@config)
    assert_equal "dhh/app", configuration.repository

    configuration = Mrsk::Configuration.new(@config.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app", configuration.repository
  end

  test "absolute image" do
    configuration = Mrsk::Configuration.new(@config)
    assert_equal "dhh/app:123", configuration.absolute_image

    configuration = Mrsk::Configuration.new(@config.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app:123", configuration.absolute_image
  end

  test "erb evaluation of yml config" do
    configuration = Mrsk::Configuration.load_file Pathname.new(File.expand_path("fixtures/deploy.erb.yml", __dir__))
    assert_equal "my-user", configuration.registry["username"]
  end
end
