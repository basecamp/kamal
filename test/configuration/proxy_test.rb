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

  test "basic auth in deploy options and command args" do
    @deploy[:proxy] = { "basic_auth" => { "username" => "abc", "password" => "123456" } }

    proxy = config.proxy
    assert_equal "abc:123456", proxy.deploy_options[:"basic-auth"]

    args = proxy.deploy_command_args(target: "172.1.0.2")
    assert_match(/--basic-auth=\S*abc:123456/, args.map(&:to_s).join(" "))
  end

  test "basic auth credentials are redacted in command args" do
    @deploy[:proxy] = { "basic_auth" => { "username" => "abc", "password" => "123456" } }

    args = config.proxy.deploy_command_args(target: "172.1.0.2")
    redacted = Kamal::Utils.redacted(args).join(" ")

    assert_includes redacted, "--basic-auth=[REDACTED]"
    assert_not_includes redacted, "123456"
  end

  test "basic auth must be a hash" do
    @deploy[:proxy] = { "basic_auth" => "abc" }
    assert_raises(Kamal::ConfigurationError) { config.proxy }
  end

  test "no basic auth option when not configured" do
    @deploy[:proxy] = { "host" => "example.com" }

    proxy = config.proxy
    assert_nil proxy.deploy_options[:"basic-auth"]
    assert_not proxy.basic_auth?
    assert_not_includes proxy.deploy_command_args(target: "172.1.0.2").join(" "), "--basic-auth"
  end

  test "basic auth with only username" do
    @deploy[:proxy] = { "basic_auth" => { "username" => "abc" } }
    assert_raises(Kamal::ConfigurationError) { config.proxy }
  end

  test "basic auth with only password" do
    @deploy[:proxy] = { "basic_auth" => { "password" => "123456" } }
    assert_raises(Kamal::ConfigurationError) { config.proxy }
  end

  test "basic auth specialized on a role overrides root proxy config" do
    @deploy[:proxy] = { "basic_auth" => { "username" => "abc", "password" => "123456" } }
    @deploy[:servers] = { "web" => { "hosts" => [ "1.1.1.1" ], "proxy" => { "basic_auth" => { "username" => "xyz", "password" => "secret" } } } }

    assert_equal "xyz:secret", config.role(:web).proxy.deploy_options[:"basic-auth"]
  end

  private
    def config
      Kamal::Configuration.new(@deploy)
    end
end
