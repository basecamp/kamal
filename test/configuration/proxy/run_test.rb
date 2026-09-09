require "test_helper"

class ConfigurationProxyRunTest < ActiveSupport::TestCase
  setup do
    ENV["RAILS_MASTER_KEY"] = "456"
    ENV["VERSION"] = "missing"
  end

  test "run objects with identical config are equal" do
    deploy = base_deploy.deep_merge(proxy: { "run" => { "log_max_size" => "50m" } })
    config = Kamal::Configuration.new(deploy)

    run_a = Kamal::Configuration::Proxy::Run.new(config, run_config: { "log_max_size" => "50m" })
    run_b = Kamal::Configuration::Proxy::Run.new(config, run_config: { "log_max_size" => "50m" })

    assert_equal run_a, run_b
    assert_equal run_a.hash, run_b.hash
    assert_equal 1, [ run_a, run_b ].uniq.size
  end

  test "run objects with different config are not equal" do
    deploy = base_deploy.deep_merge(proxy: { "run" => { "log_max_size" => "50m" } })
    config = Kamal::Configuration.new(deploy)

    run_a = Kamal::Configuration::Proxy::Run.new(config, run_config: { "log_max_size" => "50m" })
    run_b = Kamal::Configuration::Proxy::Run.new(config, run_config: { "log_max_size" => "100m" })

    assert_not_equal run_a, run_b
    assert_equal 2, [ run_a, run_b ].uniq.size
  end

  test "no conflict when global proxy run config is inherited by role proxy" do
    deploy = base_deploy.deep_merge(
      servers: {
        "web" => { "hosts" => [ "1.1.1.1" ] },
        "worker" => {
          "hosts" => [ "1.1.1.1" ],
          "cmd" => "bin/jobs",
          "proxy" => {
            "hosts" => [ "worker.example.com" ],
            "app_port" => 8080
          }
        }
      },
      proxy: {
        "hosts" => [ "example.com" ],
        "run" => {
          "log_max_size" => "",
          "options" => { "log-driver" => "journald" }
        }
      }
    )

    # Should not raise Kamal::ConfigurationError
    config = Kamal::Configuration.new(deploy)
    assert config
  end

  test "http3 is disabled by default" do
    config = Kamal::Configuration.new(base_deploy)
    run = Kamal::Configuration::Proxy::Run.new(config, run_config: {})

    assert_not run.http3?
    assert_equal "--publish 80:80 --publish 443:443", run.publish_args
    assert_not_includes run.run_command, "--http3"
  end

  test "http3 adds --http3 and publishes the https port over udp" do
    config = Kamal::Configuration.new(base_deploy)
    run = Kamal::Configuration::Proxy::Run.new(config, run_config: { "http3" => true })

    assert run.http3?
    assert_equal "--publish 80:80 --publish 443:443 --publish 443:443/udp", run.publish_args
    assert_includes run.run_command, "--http3"
  end

  test "http3 udp publish honors a custom https port" do
    config = Kamal::Configuration.new(base_deploy)
    run = Kamal::Configuration::Proxy::Run.new(config, run_config: { "http3" => true, "https_port" => 8443 })

    assert_equal "--publish 80:80 --publish 8443:443 --publish 8443:443/udp", run.publish_args
  end

  private
    def base_deploy
      {
        service: "app", image: "dhh/app",
        registry: { "username" => "dhh", "password" => "secret" },
        builder: { "arch" => "amd64" },
        servers: [ "1.1.1.1" ]
      }
    end
end
