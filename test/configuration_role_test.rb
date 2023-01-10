require "test_helper"
require "mrsk/configuration"

ENV["VERSION"] = "123"

class ConfigurationRoleTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1", "1.1.1.2" ]
    }

    @config = Mrsk::Configuration.new(@deploy)

    @deploy_with_roles = @deploy.dup.merge({
      servers: {
        "web" => [ "1.1.1.1", "1.1.1.2" ],
        "workers" => {
          "hosts" => [ "1.1.1.3", "1.1.1.4" ],
          "cmd" => "bin/jobs"
        }
      }
    })

    @config_with_roles = Mrsk::Configuration.new(@deploy_with_roles)
  end

  test "hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @config.role(:web).hosts
    assert_equal [ "1.1.1.3", "1.1.1.4" ], @config_with_roles.role(:workers).hosts
  end

  test "label args" do
    assert_equal [ "--label", "service=app", "--label", "role=workers" ], @config_with_roles.role(:workers).label_args
  end

  test "special label args for web" do
    assert_equal [ "--label", "service=app", "--label", "role=web", "--label", "traefik.http.routers.app.rule='PathPrefix(`/`)'", "--label", "traefik.http.services.app.loadbalancer.healthcheck.path=/up", "--label", "traefik.http.services.app.loadbalancer.healthcheck.interval=1s", "--label", "traefik.http.middlewares.app.retry.attempts=3", "--label", "traefik.http.middlewares.app.retry.initialinterval=500ms"], @config.role(:web).label_args
  end

  test "cmd" do
    assert_nil @config.role(:web).cmd
    assert_equal "bin/jobs", @config_with_roles.role(:workers).cmd
  end
end
