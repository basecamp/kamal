require "test_helper"

class ConfigurationSshTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      env: { "REDIS_URL" => "redis://x/y" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      volumes: ["/local/path:/container/path"]
    }

    @config = Mrsk::Configuration.new(@deploy)
  end

  test "ssh options" do
    assert_equal "root", @config.ssh.options[:user]

    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "user" => "app" }) })
    assert_equal "app", config.ssh.options[:user]
    assert_equal 4, config.ssh.options[:logger].level

    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "log_level" => "debug" }) })
    assert_equal 0, config.ssh.options[:logger].level
  end

  test "ssh options with proxy host" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "proxy" => "1.2.3.4" }) })
    assert_equal "root@1.2.3.4", config.ssh.options[:proxy].jump_proxies
  end

  test "ssh options with proxy host and user" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "proxy" => "app@1.2.3.4" }) })
    assert_equal "app@1.2.3.4", config.ssh.options[:proxy].jump_proxies
  end
end
