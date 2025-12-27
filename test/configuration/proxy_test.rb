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

  test "loadbalancer present" do
    @deploy[:proxy] = { "loadbalancer" => "lb.example.com" }
    assert_equal "lb.example.com", config.proxy.loadbalancer
  end

  test "loadbalancer not present" do
    @deploy[:proxy] = {}
    assert_nil config.proxy.loadbalancer
  end

  test "effective_loadbalancer with explicit loadbalancer" do
    @deploy[:proxy] = { "loadbalancer" => "lb.example.com" }
    assert_equal "lb.example.com", config.proxy.effective_loadbalancer
  end

  test "effective_loadbalancer with multiple web hosts but no explicit loadbalancer" do
    @deploy[:proxy] = { "hosts" => [] }
    @deploy[:servers] = { "web" => [ "web1.example.com", "web2.example.com" ] }
    assert_equal "web1.example.com", config.proxy.effective_loadbalancer
  end

  test "effective_loadbalancer with single web host and no explicit loadbalancer" do
    @deploy[:proxy] = { "hosts" => [] }
    @deploy[:servers] = { "web" => [ "web1.example.com" ] }
    assert_nil config.proxy.effective_loadbalancer
  end

  test "load_balancing? returns true when loadbalancer is present" do
    @deploy[:proxy] = { "loadbalancer" => "lb.example.com" }
    assert config.proxy.load_balancing?
  end

  test "load_balancing? returns true when multiple web hosts are present" do
    @deploy[:proxy] = { "hosts" => [] }
    @deploy[:servers] = { "web" => [ "web1.example.com", "web2.example.com" ] }
    assert config.proxy.load_balancing?
  end

  test "load_balancing? returns false when no loadbalancer and single web host" do
    @deploy[:proxy] = { "hosts" => [] }
    @deploy[:servers] = { "web" => [ "web1.example.com" ] }
    assert_not config.proxy.load_balancing?
  end

  test "deploy_options disables SSL when loadbalancer is present" do
    @deploy[:proxy] = { "loadbalancer" => "lb.example.com" }
    assert_equal false, config.proxy.deploy_options.key?(:tls)
  end

  test "deploy_options makes hosts optional when loadbalancer is present" do
    @deploy[:proxy] = { "loadbalancer" => "lb.example.com", "hosts" => [ "app1.example.com" ] }
    assert_nil config.proxy.deploy_options[:host]
  end

  test "deploy_options uses hosts when no loadbalancer is present" do
    @deploy[:proxy] = { "hosts" => [ "app1.example.com" ] }
    assert_equal [ "app1.example.com" ], config.proxy.deploy_options[:host]
  end

  test "loadbalancer_on_proxy_host? returns true when loadbalancer is a web host" do
    @deploy[:servers] = { "web" => [ "web1.example.com", "web2.example.com" ] }
    @deploy[:proxy] = { "loadbalancer" => "web1.example.com" }
    assert config.proxy.loadbalancer_on_proxy_host?
  end

  test "loadbalancer_on_proxy_host? returns false when loadbalancer is dedicated host" do
    @deploy[:servers] = { "web" => [ "web1.example.com", "web2.example.com" ] }
    @deploy[:proxy] = { "loadbalancer" => "lb.example.com" }
    assert_not config.proxy.loadbalancer_on_proxy_host?
  end

  test "loadbalancer_on_proxy_host? returns false when no loadbalancer" do
    @deploy[:servers] = { "web" => [ "web1.example.com" ] }
    @deploy[:proxy] = {}
    assert_not config.proxy.loadbalancer_on_proxy_host?
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
