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

  test "false not allowed" do
    @deploy[:proxy] = false
    assert_raises(Kamal::ConfigurationError, "proxy: should be a hash") do
      config.proxy
    end
  end

  test "ssl with certificate and private key from secrets" do
    with_test_secrets("secrets" => "CERT_PEM=certificate\nKEY_PEM=private_key") do
      @deploy[:proxy] = {
        "ssl" => {
          "certificate_pem" => "CERT_PEM",
          "private_key_pem" => "KEY_PEM"
        },
        "host" => "example.com"
      }

      proxy = config.proxy
      assert_equal ".kamal/proxy/apps-config/app/tls/cert.pem", proxy.host_tls_cert
      assert_equal ".kamal/proxy/apps-config/app/tls/key.pem", proxy.host_tls_key
      assert_equal "/home/kamal-proxy/.apps-config/app/tls/cert.pem", proxy.container_tls_cert
      assert_equal "/home/kamal-proxy/.apps-config/app/tls/key.pem", proxy.container_tls_key
    end
  end

  test "deploy options with custom ssl certificates" do
    with_test_secrets("secrets" => "CERT_PEM=certificate\nKEY_PEM=private_key") do
      @deploy[:proxy] = {
        "ssl" => {
          "certificate_pem" => "CERT_PEM",
          "private_key_pem" => "KEY_PEM"
        },
        "host" => "example.com"
      }

      proxy = config.proxy
      options = proxy.deploy_options
      assert_equal true, options[:tls]
      assert_equal "/home/kamal-proxy/.apps-config/app/tls/cert.pem", options[:"tls-certificate-path"]
      assert_equal "/home/kamal-proxy/.apps-config/app/tls/key.pem", options[:"tls-private-key-path"]
    end
  end

  test "healthcheck options are passed through to the proxy" do
    @deploy[:proxy] = {
      "host" => "example.com",
      "healthcheck" => {
        "protocol" => "websocket",
        "path" => "/mqtt",
        "websocket_subprotocol" => "mqtt"
      }
    }

    options = config.proxy.deploy_options
    assert_equal "websocket", options[:"health-check-protocol"]
    assert_equal "/mqtt", options[:"health-check-path"]
    assert_equal "mqtt", options[:"health-check-websocket-subprotocol"]
  end

  test "an empty healthcheck protocol passes no flag" do
    @deploy[:proxy] = { "host" => "example.com", "healthcheck" => { "protocol" => "" } }

    assert_not config.proxy.deploy_options.key?(:"health-check-protocol")
  end

  test "an unknown healthcheck protocol is rejected" do
    @deploy[:proxy] = { "host" => "example.com", "healthcheck" => { "protocol" => "websockets" } }

    error = assert_raises(Kamal::ConfigurationError) { config.proxy }
    assert_match(/Invalid healthcheck protocol: websockets/, error.message)
  end

  test "a websocket subprotocol without the websocket protocol is rejected" do
    [ nil, "http" ].each do |protocol|
      healthcheck = { "websocket_subprotocol" => "mqtt" }
      healthcheck["protocol"] = protocol if protocol
      @deploy[:proxy] = { "host" => "example.com", "healthcheck" => healthcheck }

      error = assert_raises(Kamal::ConfigurationError) { config.proxy }
      assert_match(/websocket_subprotocol/, error.message)
    end
  end

  test "the supported healthcheck protocols are accepted" do
    [ "http", "websocket" ].each do |protocol|
      @deploy[:proxy] = { "host" => "example.com", "healthcheck" => { "protocol" => protocol } }
      assert_equal protocol, config.proxy.deploy_options[:"health-check-protocol"]
    end
  end

  test "healthcheck options are omitted when unset" do
    @deploy[:proxy] = { "host" => "example.com" }

    options = config.proxy.deploy_options
    assert_not options.key?(:"health-check-protocol")
    assert_not options.key?(:"health-check-websocket-subprotocol")
  end

  test "ssl with certificate and no private key" do
    with_test_secrets("secrets" => "CERT_PEM=certificate") do
      @deploy[:proxy] = {
        "ssl" => {
          "certificate_pem" => "CERT_PEM"
        },
        "host" => "example.com"
      }
      assert_raises(Kamal::ConfigurationError) { config.proxy.ssl? }
    end
  end

  test "ssl with private key and no certificate" do
    with_test_secrets("secrets" => "KEY_PEM=private_key") do
      @deploy[:proxy] = {
        "ssl" => {
          "private_key_pem" => "KEY_PEM"
        },
        "host" => "example.com"
      }
      assert_raises(Kamal::ConfigurationError) { config.proxy.ssl? }
    end
  end

  private
    def config
      Kamal::Configuration.new(@deploy)
    end
end
