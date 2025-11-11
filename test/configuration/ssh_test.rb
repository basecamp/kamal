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

    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "config" => true }) })
    assert_equal true, config.ssh.options[:config]

    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "config" => false }) })
    assert_equal false, config.ssh.options[:config]

    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "config" => "~/config.mine" }) })
    assert_equal "~/config.mine", config.ssh.options[:config]

    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "config" => [ "~/config.mine.1", "~/config.mine.2" ] }) })
    assert_equal [ "~/config.mine.1", "~/config.mine.2" ], config.ssh.options[:config]
  end

  test "ssh options with proxy host" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "proxy" => "1.2.3.4" }) })
    assert_equal "root@1.2.3.4", config.ssh.options[:proxy].jump_proxies
  end

  test "ssh options with proxy host and user" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "proxy" => "app@1.2.3.4" }) })
    assert_equal "app@1.2.3.4", config.ssh.options[:proxy].jump_proxies
  end

  test "ssh key_data with plain value array" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "key_data" => [ "-----BEGIN OPENSSH PRIVATE KEY-----" ] }) })
    assert_equal [ "-----BEGIN OPENSSH PRIVATE KEY-----" ], config.ssh.options[:key_data]
  end

  test "ssh key_data with array containing one secret string" do
    with_test_secrets("secrets" => "SSH_PRIVATE_KEY=secret_ssh_key") do
      config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "key_data" => [ "SSH_PRIVATE_KEY" ] }) })
      assert_equal [ "secret_ssh_key" ], config.ssh.options[:key_data]
    end
  end

  test "ssh key_data with array containing multiple secret strings" do
    with_test_secrets("secrets" => "SSH_PRIVATE_KEY=secret_ssh_key\nSECOND_KEY=second_secret_ssh_key") do
      config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "key_data" => [ "SSH_PRIVATE_KEY", "SECOND_KEY" ] }) })
      assert_equal [ "secret_ssh_key", "second_secret_ssh_key" ], config.ssh.options[:key_data]
    end
  end
end
