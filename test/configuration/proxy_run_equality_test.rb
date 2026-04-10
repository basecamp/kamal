require "test_helper"

class ConfigurationProxyRunEqualityTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      builder: { "arch" => "amd64" },
      servers: {
        "web" => { "hosts" => [ "1.2.3.4" ] },
        "worker" => {
          "hosts" => [ "1.2.3.4" ],
          "proxy" => { "hosts" => [ "worker.example.com" ], "app_port" => 8080 }
        }
      },
      proxy: {
        "hosts" => [ "example.com" ],
        "run" => { "log_max_size" => "", "options" => { "log-driver" => "journald" } }
      }
    }
  end

  test "identical proxy run configs across roles on same host do not conflict" do
    config = Kamal::Configuration.new(@deploy)
    assert_not_nil config
  end

  test "different proxy run configs across roles on same host raise conflict" do
    deploy = @deploy.merge(servers: @deploy[:servers].merge(
      "web" => { "hosts" => [ "1.2.3.4" ], "proxy" => { "hosts" => [ "example.com" ], "run" => { "log_max_size" => "5m" } } },
      "worker" => { "hosts" => [ "1.2.3.4" ], "proxy" => { "hosts" => [ "worker.example.com" ], "run" => { "log_max_size" => "10m" } } }
    ))

    assert_raises(Kamal::ConfigurationError) { Kamal::Configuration.new(deploy) }
  end

  test "Run objects with identical run_config are equal" do
    config = Kamal::Configuration.new(@deploy)
    run_config = { "log_max_size" => "10m" }

    run1 = Kamal::Configuration::Proxy::Run.new(config, run_config: run_config)
    run2 = Kamal::Configuration::Proxy::Run.new(config, run_config: run_config)

    assert_equal run1, run2
    assert_equal run1.hash, run2.hash
    assert_equal [ run1 ], [ run1, run2 ].uniq
  end

  test "Run objects with different run_config are not equal" do
    config = Kamal::Configuration.new(@deploy)

    run1 = Kamal::Configuration::Proxy::Run.new(config, run_config: { "log_max_size" => "5m" })
    run2 = Kamal::Configuration::Proxy::Run.new(config, run_config: { "log_max_size" => "10m" })

    assert_not_equal run1, run2
    assert_equal 2, [ run1, run2 ].uniq.size
  end
end
