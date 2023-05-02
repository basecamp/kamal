require "test_helper"

class ConfigurationRoleTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      env: { "REDIS_URL" => "redis://x/y" }
    }

    @config = Mrsk::Configuration.new(@deploy)

    @deploy_with_roles = @deploy.dup.merge({
      servers: {
        "web" => [ "1.1.1.1", "1.1.1.2" ],
        "workers" => {
          "hosts" => [ "1.1.1.3", "1.1.1.4" ],
          "cmd" => "bin/jobs",
          "env" => {
            "REDIS_URL" => "redis://a/b",
            "WEB_CONCURRENCY" => 4
          }
        }
      }
    })

    @config_with_roles = Mrsk::Configuration.new(@deploy_with_roles)
  end

  test "hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @config.role(:web).hosts
    assert_equal [ "1.1.1.3", "1.1.1.4" ], @config_with_roles.role(:workers).hosts
  end

  test "cmd" do
    assert_nil @config.role(:web).cmd
    assert_equal "bin/jobs", @config_with_roles.role(:workers).cmd
  end

  test "label args" do
    assert_equal [ "--label", "service=\"app\"", "--label", "role=\"workers\"" ], @config_with_roles.role(:workers).label_args
  end

  test "special label args for web" do
    assert_equal [ "--label", "service=\"app\"", "--label", "role=\"web\"", "--label", "traefik.http.services.app-web.loadbalancer.server.scheme=\"http\"", "--label", "traefik.http.routers.app-web.rule=\"PathPrefix(\\`/\\`)\"", "--label", "traefik.http.middlewares.app-web-retry.retry.attempts=\"5\"", "--label", "traefik.http.middlewares.app-web-retry.retry.initialinterval=\"500ms\"", "--label", "traefik.http.routers.app-web.middlewares=\"app-web-retry@docker\"" ], @config.role(:web).label_args
  end

  test "custom labels" do
    @deploy[:labels] = { "my.custom.label" => "50" }
    assert_equal "50", @config.role(:web).labels["my.custom.label"]
  end

  test "custom labels via role specialization" do
    @deploy_with_roles[:labels] = { "my.custom.label" => "50" }
    @deploy_with_roles[:servers]["workers"]["labels"] = { "my.custom.label" => "70" }
    assert_equal "70", @config_with_roles.role(:workers).labels["my.custom.label"]
  end

  test "overwriting default traefik label" do
    @deploy[:labels] = { "traefik.http.routers.app-web.rule" => "\"Host(\\`example.com\\`) || (Host(\\`example.org\\`) && Path(\\`/traefik\\`))\"" }
    assert_equal "\"Host(\\`example.com\\`) || (Host(\\`example.org\\`) && Path(\\`/traefik\\`))\"", @config.role(:web).labels["traefik.http.routers.app-web.rule"]
  end

  test "default traefik label on non-web role" do
    config = Mrsk::Configuration.new(@deploy_with_roles.tap { |c|
      c[:servers]["beta"] = { "traefik" => "true", "hosts" => [ "1.1.1.5" ] }
    })

    assert_equal [ "--label", "service=\"app\"", "--label", "role=\"beta\"", "--label", "traefik.http.services.app-beta.loadbalancer.server.scheme=\"http\"", "--label", "traefik.http.routers.app-beta.rule=\"PathPrefix(\\`/\\`)\"", "--label", "traefik.http.middlewares.app-beta-retry.retry.attempts=\"5\"", "--label", "traefik.http.middlewares.app-beta-retry.retry.initialinterval=\"500ms\"", "--label", "traefik.http.routers.app-beta.middlewares=\"app-beta-retry@docker\"" ], config.role(:beta).label_args
  end

  test "env overwritten by role" do
    assert_equal "redis://a/b", @config_with_roles.role(:workers).env["REDIS_URL"]
    assert_equal ["-e", "REDIS_URL=\"redis://a/b\"", "-e", "WEB_CONCURRENCY=\"4\""], @config_with_roles.role(:workers).env_args
  end

  test "env secret overwritten by role" do
    @deploy_with_roles[:env] = {
      "clear" => {
        "REDIS_URL" => "redis://a/b"
      },
      "secret" => [
        "REDIS_PASSWORD"
      ]
    }

    @deploy_with_roles[:servers]["workers"]["env"] = {
      "clear" => {
        "REDIS_URL" => "redis://a/b",
        "WEB_CONCURRENCY" => 4
      },
      "secret" => [
        "DB_PASSWORD"
      ]
    }

    ENV["REDIS_PASSWORD"] = "secret456"
    ENV["DB_PASSWORD"] = "secret&\"123"

    @config_with_roles.role(:workers).env_args.tap do |env_args|
      assert_equal ["-e", "REDIS_PASSWORD=\"secret456\"", "-e", "DB_PASSWORD=\"secret&\\\"123\"", "-e", "REDIS_URL=\"redis://a/b\"", "-e", "WEB_CONCURRENCY=\"4\""], Mrsk::Utils.unredacted(env_args)
      assert_equal ["-e", "REDIS_PASSWORD=[REDACTED]", "-e", "DB_PASSWORD=[REDACTED]", "-e", "REDIS_URL=\"redis://a/b\"", "-e", "WEB_CONCURRENCY=\"4\""], Mrsk::Utils.redacted(env_args)
    end
  ensure
    ENV["REDIS_PASSWORD"] = nil
    ENV["DB_PASSWORD"] = nil
  end

  test "env secrets only in role" do
    @deploy_with_roles[:servers]["workers"]["env"] = {
      "clear" => {
        "REDIS_URL" => "redis://a/b",
        "WEB_CONCURRENCY" => 4
      },
      "secret" => [
        "DB_PASSWORD"
      ]
    }

    ENV["DB_PASSWORD"] = "secret123"

    @config_with_roles.role(:workers).env_args.tap do |env_args|
      assert_equal ["-e", "DB_PASSWORD=\"secret123\"", "-e", "REDIS_URL=\"redis://a/b\"", "-e", "WEB_CONCURRENCY=\"4\""], Mrsk::Utils.unredacted(env_args)
      assert_equal ["-e", "DB_PASSWORD=[REDACTED]", "-e", "REDIS_URL=\"redis://a/b\"", "-e", "WEB_CONCURRENCY=\"4\""], Mrsk::Utils.redacted(env_args)
    end
  ensure
    ENV["DB_PASSWORD"] = nil
  end

  test "env secrets only at top level" do
    @deploy_with_roles[:env] = {
      "clear" => {
        "REDIS_URL" => "redis://a/b"
      },
      "secret" => [
        "REDIS_PASSWORD"
      ]
    }

    ENV["REDIS_PASSWORD"] = "secret456"

    @config_with_roles.role(:workers).env_args.tap do |env_args|
      assert_equal ["-e", "REDIS_PASSWORD=\"secret456\"", "-e", "REDIS_URL=\"redis://a/b\"", "-e", "WEB_CONCURRENCY=\"4\""], Mrsk::Utils.unredacted(env_args)
      assert_equal ["-e", "REDIS_PASSWORD=[REDACTED]", "-e", "REDIS_URL=\"redis://a/b\"", "-e", "WEB_CONCURRENCY=\"4\""], Mrsk::Utils.redacted(env_args)
    end
  ensure
    ENV["REDIS_PASSWORD"] = nil
  end
end
