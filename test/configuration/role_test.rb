require "test_helper"

class ConfigurationRoleTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      builder: { "arch" => "amd64" },
      env: { "REDIS_URL" => "redis://x/y" }
    }

    @deploy_with_roles = @deploy.dup.merge({
      servers: {
        "web" => [ "1.1.1.1", "1.1.1.2" ],
        "workers" => {
          "hosts" => [ "1.1.1.3", "1.1.1.4" ],
          "cmd" => "bin/jobs",
          "env" => {
            "REDIS_URL" => "redis://a/b",
            "WEB_CONCURRENCY" => "4"
          }
        }
      }
    })
  end

  test "hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2" ], config.role(:web).hosts
    assert_equal [ "1.1.1.3", "1.1.1.4" ], config_with_roles.role(:workers).hosts
  end

  test "cmd" do
    assert_nil config.role(:web).cmd
    assert_equal "bin/jobs", config_with_roles.role(:workers).cmd
  end

  test "label args" do
    assert_equal [ "--label", "service=\"app\"", "--label", "role=\"workers\"", "--label", "destination" ], config_with_roles.role(:workers).label_args
  end

  test "special label args for web" do
    assert_equal [ "--label", "service=\"app\"", "--label", "role=\"web\"", "--label", "destination" ], config.role(:web).label_args
  end

  test "custom labels" do
    @deploy[:labels] = { "my.custom.label" => "50" }
    assert_equal "50", config.role(:web).labels["my.custom.label"]
  end

  test "custom labels via role specialization" do
    @deploy_with_roles[:labels] = { "my.custom.label" => "50" }
    @deploy_with_roles[:servers]["workers"]["labels"] = { "my.custom.label" => "70" }
    assert_equal "70", Kamal::Configuration.new(@deploy_with_roles).role(:workers).labels["my.custom.label"]
  end

  test "default proxy label on non-web role" do
    config = Kamal::Configuration.new(@deploy_with_roles.tap { |c|
      c[:servers]["beta"] = { "proxy" => true, "hosts" => [ "1.1.1.5" ] }
    })

    assert_equal [ "--label", "service=\"app\"", "--label", "role=\"beta\"", "--label", "destination" ], config.role(:beta).label_args
  end

  test "env overwritten by role" do
    assert_equal "redis://a/b", config_with_roles.role(:workers).env("1.1.1.3").clear["REDIS_URL"]

    assert_equal \
      [ "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"", "--env-file", ".kamal/apps/app/env/roles/workers.env" ],
      config_with_roles.role(:workers).env_args("1.1.1.3").map(&:to_s)

    assert_equal \
      "\n",
      config_with_roles.role(:workers).secrets_io("1.1.1.3").read
  end

  test "container name" do
    ENV["VERSION"] = "12345"

    assert_equal "app-workers-12345", config_with_roles.role(:workers).container_name
    assert_equal "app-web-12345", config_with_roles.role(:web).container_name
  ensure
    ENV.delete("VERSION")
  end

  test "env args" do
    assert_equal \
      [ "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"", "--env-file", ".kamal/apps/app/env/roles/workers.env" ],
      config_with_roles.role(:workers).env_args("1.1.1.3").map(&:to_s)

    assert_equal \
      "\n",
      config_with_roles.role(:workers).secrets_io("1.1.1.3").read
  end

  test "env secret overwritten by role" do
    with_test_secrets("secrets" => "REDIS_PASSWORD=secret456\nDB_PASSWORD=secret&\"123") do
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
          "WEB_CONCURRENCY" => "4"
        },
        "secret" => [
          "DB_PASSWORD"
        ]
      }

      assert_equal \
        [ "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"", "--env-file", ".kamal/apps/app/env/roles/workers.env" ],
        config_with_roles.role(:workers).env_args("1.1.1.3").map(&:to_s)

      assert_equal \
        "REDIS_PASSWORD=secret456\nDB_PASSWORD=secret&\"123\n",
        config_with_roles.role(:workers).secrets_io("1.1.1.3").read
    end
  end

  test "env secrets only in role" do
    with_test_secrets("secrets" => "DB_PASSWORD=secret123") do
      @deploy_with_roles[:servers]["workers"]["env"] = {
        "clear" => {
          "REDIS_URL" => "redis://a/b",
          "WEB_CONCURRENCY" => "4"
        },
        "secret" => [
          "DB_PASSWORD"
        ]
      }

      assert_equal \
        [ "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"", "--env-file", ".kamal/apps/app/env/roles/workers.env" ],
        config_with_roles.role(:workers).env_args("1.1.1.3").map(&:to_s)

      assert_equal \
        "DB_PASSWORD=secret123\n",
        config_with_roles.role(:workers).secrets_io("1.1.1.3").read
    end
  end

  test "env secrets only at top level" do
    with_test_secrets("secrets" => "REDIS_PASSWORD=secret456") do
      @deploy_with_roles[:env] = {
        "clear" => {
          "REDIS_URL" => "redis://a/b"
        },
        "secret" => [
          "REDIS_PASSWORD"
        ]
      }

      assert_equal \
        [ "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"", "--env-file", ".kamal/apps/app/env/roles/workers.env" ],
        config_with_roles.role(:workers).env_args("1.1.1.3").map(&:to_s)

      assert_equal \
        "REDIS_PASSWORD=secret456\n",
        config_with_roles.role(:workers).secrets_io("1.1.1.3").read
    end
  end

  test "env overwritten by role with secrets" do
    with_test_secrets("secrets" => "REDIS_PASSWORD=secret456") do
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
          "REDIS_URL" => "redis://c/d"
        }
      }

      assert_equal \
        [ "--env", "REDIS_URL=\"redis://c/d\"", "--env-file", ".kamal/apps/app/env/roles/workers.env" ],
        config_with_roles.role(:workers).env_args("1.1.1.3").map(&:to_s)

      assert_equal \
        "REDIS_PASSWORD=secret456\n",
        config_with_roles.role(:workers).secrets_io("1.1.1.3").read
    end
  end

  test "asset path and volume args" do
    ENV["VERSION"] = "12345"
    assert_nil config_with_roles.role(:web).asset_volume_args
    assert_nil config_with_roles.role(:workers).asset_volume_args
    assert_nil config_with_roles.role(:web).asset_path
    assert_nil config_with_roles.role(:workers).asset_path
    assert_not config_with_roles.role(:web).assets?
    assert_not config_with_roles.role(:workers).assets?

    config_with_assets = Kamal::Configuration.new(@deploy_with_roles.dup.tap { |c|
      c[:asset_path] = "foo"
    })
    assert_equal "foo", config_with_assets.role(:web).asset_path
    assert_equal "foo", config_with_assets.role(:workers).asset_path
    assert_equal [ "--volume", "$(pwd)/.kamal/apps/app/assets/volumes/web-12345:foo" ], config_with_assets.role(:web).asset_volume_args
    assert_nil config_with_assets.role(:workers).asset_volume_args
    assert config_with_assets.role(:web).assets?
    assert_not config_with_assets.role(:workers).assets?

    config_with_assets = Kamal::Configuration.new(@deploy_with_roles.dup.tap { |c|
      c[:servers]["web"] = { "hosts" => [ "1.1.1.1", "1.1.1.2" ], "asset_path" => "bar" }
    })
    assert_equal "bar", config_with_assets.role(:web).asset_path
    assert_nil config_with_assets.role(:workers).asset_path
    assert_equal [ "--volume", "$(pwd)/.kamal/apps/app/assets/volumes/web-12345:bar" ], config_with_assets.role(:web).asset_volume_args
    assert_nil config_with_assets.role(:workers).asset_volume_args
    assert config_with_assets.role(:web).assets?
    assert_not config_with_assets.role(:workers).assets?

  ensure
    ENV.delete("VERSION")
  end

  test "asset extracted path" do
    ENV["VERSION"] = "12345"
    assert_equal ".kamal/apps/app/assets/extracted/web-12345", config_with_roles.role(:web).asset_extracted_directory
    assert_equal ".kamal/apps/app/assets/extracted/workers-12345", config_with_roles.role(:workers).asset_extracted_directory
  ensure
    ENV.delete("VERSION")
  end

  test "asset volume path" do
    ENV["VERSION"] = "12345"
    assert_equal ".kamal/apps/app/assets/volumes/web-12345", config_with_roles.role(:web).asset_volume_directory
    assert_equal ".kamal/apps/app/assets/volumes/workers-12345", config_with_roles.role(:workers).asset_volume_directory
  ensure
    ENV.delete("VERSION")
  end

  test "stop args with proxy" do
    assert_equal [], config_with_roles.role(:web).stop_args
  end

  test "stop args with no proxy" do
    assert_equal [ "-t", 30 ], config_with_roles.role(:workers).stop_args
  end

  test "role specific proxy config" do
    @deploy_with_roles[:proxy] = { "response_timeout" => 15 }
    @deploy_with_roles[:servers]["workers"]["proxy"] = { "response_timeout" => 18 }

    assert_equal "15s", config_with_roles.role(:web).proxy.deploy_options[:"target-timeout"]
    assert_equal "18s", config_with_roles.role(:workers).proxy.deploy_options[:"target-timeout"]
  end

  private
    def config
      Kamal::Configuration.new(@deploy)
    end

    def config_with_roles
      Kamal::Configuration.new(@deploy_with_roles)
    end
end
