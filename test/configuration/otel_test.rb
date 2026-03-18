require "test_helper"

class ConfigurationOtelTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      builder: { "arch" => "amd64" },
      servers: [ "1.1.1.1" ]
    }
  end

  test "otel disabled by default" do
    config = Kamal::Configuration.new(@deploy)
    assert_not config.otel.enabled?
    assert_nil config.otel.endpoint
  end

  test "otel enabled with endpoint" do
    @deploy[:otel] = { "endpoint" => "http://otel-gateway:4318" }
    config = Kamal::Configuration.new(@deploy)

    assert config.otel.enabled?
    assert_equal "http://otel-gateway:4318", config.otel.endpoint
  end

  test "otel derives service_namespace from service" do
    @deploy[:otel] = { "endpoint" => "http://otel-gateway:4318" }
    config = Kamal::Configuration.new(@deploy)

    assert_equal "app", config.otel.service_namespace
  end

  test "otel derives environment from destination" do
    @deploy[:otel] = { "endpoint" => "http://otel-gateway:4318" }
    config = Kamal::Configuration.new(@deploy, destination: "production")

    assert_equal "production", config.otel.environment
  end
end
