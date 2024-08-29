require "test_helper"

class ConfigurationSshTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      builder: { "arch" => "amd64" },
      env: { "REDIS_URL" => "redis://x/y" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      volumes: [ "/local/path:/container/path" ]
    }

    @config = Kamal::Configuration.new(@deploy)
  end

  test "ssh options" do
    assert_equal "root", @config.ssh.options[:user]

    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "user" => "app" }) })
    assert_equal "app", config.ssh.options[:user]
    assert_equal 4, config.ssh.options[:logger].level

    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "log_level" => "debug" }) })
    assert_equal 0, config.ssh.options[:logger].level

    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "port" => 2222 }) })
    assert_equal 2222, config.ssh.options[:port]
  end

  test "ssh options with proxy host" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "proxy" => "1.2.3.4" }) })
    assert_equal "root@1.2.3.4", config.ssh.options[:proxy].jump_proxies
  end

  test "ssh options with proxy host and user" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "proxy" => "app@1.2.3.4" }) })
    assert_equal "app@1.2.3.4", config.ssh.options[:proxy].jump_proxies
  end
end
