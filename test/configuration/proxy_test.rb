require "test_helper"

class ConfigurationProxyTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      builder: { "arch" => "amd64" }, servers: [ "1.1.1.1" ]
    }
  end

  test "ssl with host" do
    @deploy[:proxy] = { "ssl" => true, "host" => "example.com" }
    assert_equal true, config.proxy.ssl?
  end

  test "ssl with multiple hosts passed via host" do
    @deploy[:proxy] = { "ssl" => true, "host" => "example.com,anotherexample.com" }
    assert_equal true, config.proxy.ssl?
  end

  test "ssl with multiple hosts passed via hosts" do
    @deploy[:proxy] = { "ssl" => true, "hosts" => [ "example.com", "anotherexample.com" ] }
    assert_equal true, config.proxy.ssl?
  end

  test "ssl with no host" do
    @deploy[:proxy] = { "ssl" => true }
    assert_raises(Kamal::ConfigurationError) { config.proxy.ssl? }
  end

  test "ssl with both host and hosts" do
    @deploy[:proxy] = { "ssl" => true, host: "example.com", hosts: [ "anotherexample.com" ] }
    assert_raises(Kamal::ConfigurationError) { config.proxy.ssl? }
  end

  test "ssl false" do
    @deploy[:proxy] = { "ssl" => false }
    assert_not config.proxy.ssl?
  end

  private
    def config
      Kamal::Configuration.new(@deploy)
    end
end
