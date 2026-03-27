require "test_helper"

class ConfigurationOutputTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      builder: { "arch" => "amd64" },
      servers: [ "1.1.1.1" ]
    }
    Kamal::OtelShipper.any_instance.stubs(:start_flush_thread)
  end

  teardown do
    @config&.output&.loggers&.each(&:close)
  end

  test "disabled by default" do
    @config = Kamal::Configuration.new(@deploy)
    assert_not @config.output.enabled?
    assert_empty @config.output.loggers
  end

  test "enabled with otel endpoint" do
    @deploy[:output] = { "otel" => { "endpoint" => "http://otel-gateway:4318" } }
    @config = Kamal::Configuration.new(@deploy)

    assert @config.output.enabled?
    assert_equal 1, @config.output.loggers.length
    assert_kind_of Kamal::Output::OtelLogger, @config.output.loggers.first
  end

  test "enabled with file path" do
    @deploy[:output] = { "file" => { "path" => "/var/log/kamal/" } }
    @config = Kamal::Configuration.new(@deploy)

    assert @config.output.enabled?
    assert_equal 1, @config.output.loggers.length
    assert_kind_of Kamal::Output::FileLogger, @config.output.loggers.first
  end

  test "enabled with both otel and file" do
    @deploy[:output] = {
      "otel" => { "endpoint" => "http://otel-gateway:4318" },
      "file" => { "path" => "/var/log/kamal/" }
    }
    @config = Kamal::Configuration.new(@deploy)

    assert @config.output.enabled?
    assert_equal 2, @config.output.loggers.length
  end

  test "empty output section is not enabled" do
    @deploy[:output] = {}
    @config = Kamal::Configuration.new(@deploy)

    assert_not @config.output.enabled?
    assert_empty @config.output.loggers
  end

  test "otel without endpoint raises" do
    @deploy[:output] = { "otel" => {} }

    assert_raises(ArgumentError, "OTel endpoint is required") do
      Kamal::Configuration.new(@deploy)
    end
  end

  test "file without path raises" do
    @deploy[:output] = { "file" => {} }

    assert_raises(ArgumentError, "file path is required") do
      Kamal::Configuration.new(@deploy)
    end
  end
end
