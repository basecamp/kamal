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

  test "tls_on_demand_url with no host" do
    @deploy[:proxy] = { "ssl" => true, "tls_on_demand_url" => "/up/tls_on_demand" }
    assert_equal "/up/tls_on_demand", config.proxy.tls_on_demand_url
    assert_includes config.proxy.deploy_command_args(target: "172.1.0.2"), "--tls-on-demand-url=\"/up/tls_on_demand\""
  end

  test "tls_on_demand_url with an absolute url" do
    @deploy[:proxy] = { "ssl" => true, "tls_on_demand_url" => "https://example.com/allowed" }
    assert_equal "https://example.com/allowed", config.proxy.tls_on_demand_url
  end

  test "tls_on_demand_url omitted when not set" do
    @deploy[:proxy] = { "ssl" => true, "host" => "example.com" }
    assert_nil config.proxy.tls_on_demand_url
    assert_not config.proxy.deploy_command_args(target: "172.1.0.2").any? { |arg| arg.start_with?("--tls-on-demand-url") }
  end

  test "tls_on_demand_url requires ssl" do
    @deploy[:proxy] = { "tls_on_demand_url" => "/up/tls_on_demand" }
    assert_raises(Kamal::ConfigurationError) { config.proxy.ssl? }
  end

  test "tls_on_demand_url cannot be combined with a host" do
    @deploy[:proxy] = { "ssl" => true, "host" => "example.com", "tls_on_demand_url" => "/up/tls_on_demand" }
    assert_raises(Kamal::ConfigurationError) { config.proxy.ssl? }
  end

  test "tls_on_demand_url cannot be combined with a custom certificate" do
    @deploy[:proxy] = {
      "ssl" => { "certificate_pem" => "CERTIFICATE_PEM", "private_key_pem" => "PRIVATE_KEY_PEM" },
      "tls_on_demand_url" => "/up/tls_on_demand"
    }
    assert_raises(Kamal::ConfigurationError) { config.proxy.ssl? }
  end

  test "tls_on_demand_url accepts paths and absolute http(s) urls" do
    [ "/up/tls_on_demand", "/", "https://example.com/allowed", "HTTP://example.com", "http://example.com:8080/a" ].each do |url|
      @deploy[:proxy] = { "ssl" => true, "tls_on_demand_url" => url }
      assert_equal url, config.proxy.tls_on_demand_url, "#{url} should be allowed"
    end
  end

  test "tls_on_demand_url rejects anything else" do
    [ "//example.com/allowed", "https://", "ftp://example.com", "example.com", "", 123, true ].each do |url|
      @deploy[:proxy] = { "ssl" => true, "tls_on_demand_url" => url }
      assert_raises(Kamal::ConfigurationError, "#{url.inspect} should be rejected") { config.proxy.ssl? }
    end
  end

  test "a blank tls_on_demand_url is rejected rather than passed to the proxy" do
    @deploy[:proxy] = { "ssl" => true, "host" => "example.com", "tls_on_demand_url" => "" }
    assert_raises(Kamal::ConfigurationError) { config.proxy.deploy_command_args(target: "172.1.0.2") }
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
