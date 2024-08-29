require "test_helper"

class ConfigurationSshkitTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      env: { "REDIS_URL" => "redis://x/y" },
      builder: { "arch" => "amd64" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      volumes: [ "/local/path:/container/path" ]
    }

    @config = Kamal::Configuration.new(@deploy)
  end

  test "sshkit max concurrent starts" do
    assert_equal 30, @config.sshkit.max_concurrent_starts
    @config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(sshkit: { "max_concurrent_starts" => 50 }) })
    assert_equal 50, @config.sshkit.max_concurrent_starts
  end

  test "sshkit pool idle timeout" do
    assert_equal 900, @config.sshkit.pool_idle_timeout
    @config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(sshkit: { "pool_idle_timeout" => 600 }) })
    assert_equal 600, @config.sshkit.pool_idle_timeout
  end
end
