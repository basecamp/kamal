require "test_helper"

class ConfigurationRoleTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      env: { "REDIS_URL" => "redis://x/y" }
    }

    @config = Kamal::Configuration.new(@deploy)

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

    @config_with_roles = Kamal::Configuration.new(@deploy_with_roles)
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
    assert_equal [ "--label", "service=\"app\"", "--label", "role=\"workers\"", "--label", "destination" ], @config_with_roles.role(:workers).label_args
  end

  test "special label args for web" do
    assert_equal [ "--label", "service=\"app\"", "--label", "role=\"web\"", "--label", "destination" ], @config.role(:web).label_args
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

  test "env overwritten by role" do
    assert_equal "redis://a/b", @config_with_roles.role(:workers).env("1.1.1.3").clear["REDIS_URL"]

    assert_equal "\n", @config_with_roles.role(:workers).env("1.1.1.3").secrets_io.string
    assert_equal [ "--env-file", ".kamal/env/roles/app-workers.env", "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"" ], @config_with_roles.role(:workers).env_args("1.1.1.3")
  end

  test "container name" do
    ENV["VERSION"] = "12345"

    assert_equal "app-workers-12345", @config_with_roles.role(:workers).container_name
    assert_equal "app-web-12345", @config_with_roles.role(:web).container_name
  ensure
    ENV.delete("VERSION")
  end

  test "env args" do
    assert_equal [ "--env-file", ".kamal/env/roles/app-workers.env", "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"" ], @config_with_roles.role(:workers).env_args("1.1.1.3")
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

    expected_secrets_file = <<~ENV
      REDIS_PASSWORD=secret456
      DB_PASSWORD=secret&\"123
    ENV

    assert_equal expected_secrets_file, @config_with_roles.role(:workers).env("1.1.1.3").secrets_io.string
    assert_equal [ "--env-file", ".kamal/env/roles/app-workers.env", "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"" ], @config_with_roles.role(:workers).env_args("1.1.1.3")
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

    expected_secrets_file = <<~ENV
      DB_PASSWORD=secret123
    ENV

    assert_equal expected_secrets_file, @config_with_roles.role(:workers).env("1.1.1.3").secrets_io.string
    assert_equal [ "--env-file", ".kamal/env/roles/app-workers.env", "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"" ], @config_with_roles.role(:workers).env_args("1.1.1.3")
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

    expected_secrets_file = <<~ENV
      REDIS_PASSWORD=secret456
    ENV

    assert_equal expected_secrets_file, @config_with_roles.role(:workers).env("1.1.1.3").secrets_io.string
    assert_equal [ "--env-file", ".kamal/env/roles/app-workers.env", "--env", "REDIS_URL=\"redis://a/b\"", "--env", "WEB_CONCURRENCY=\"4\"" ], @config_with_roles.role(:workers).env_args("1.1.1.3")
  ensure
    ENV["REDIS_PASSWORD"] = nil
  end

  test "env overwritten by role with secrets" do
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

    ENV["REDIS_PASSWORD"] = "secret456"

    expected_secrets_file = <<~ENV
      REDIS_PASSWORD=secret456
    ENV

    assert_equal expected_secrets_file, @config_with_roles.role(:workers).env("1.1.1.3").secrets_io.string
    assert_equal [ "--env-file", ".kamal/env/roles/app-workers.env", "--env", "REDIS_URL=\"redis://c/d\"" ], @config_with_roles.role(:workers).env_args("1.1.1.3")
  ensure
    ENV["REDIS_PASSWORD"] = nil
  end

  test "env secrets_file" do
    assert_equal ".kamal/env/roles/app-workers.env", @config_with_roles.role(:workers).env("1.1.1.3").secrets_file
  end

  test "asset path and volume args" do
    ENV["VERSION"] = "12345"
    assert_nil @config_with_roles.role(:web).asset_volume_args
    assert_nil @config_with_roles.role(:workers).asset_volume_args
    assert_nil @config_with_roles.role(:web).asset_path
    assert_nil @config_with_roles.role(:workers).asset_path
    assert_not @config_with_roles.role(:web).assets?
    assert_not @config_with_roles.role(:workers).assets?

    config_with_assets = Kamal::Configuration.new(@deploy_with_roles.dup.tap { |c|
      c[:asset_path] = "foo"
    })
    assert_equal "foo", config_with_assets.role(:web).asset_path
    assert_equal "foo", config_with_assets.role(:workers).asset_path
    assert_equal [ "--volume", "$(pwd)/.kamal/assets/volumes/app-web-12345:foo" ], config_with_assets.role(:web).asset_volume_args
    assert_nil config_with_assets.role(:workers).asset_volume_args
    assert config_with_assets.role(:web).assets?
    assert_not config_with_assets.role(:workers).assets?

    config_with_assets = Kamal::Configuration.new(@deploy_with_roles.dup.tap { |c|
      c[:servers]["web"] = { "hosts" => [ "1.1.1.1", "1.1.1.2" ], "asset_path" => "bar" }
    })
    assert_equal "bar", config_with_assets.role(:web).asset_path
    assert_nil config_with_assets.role(:workers).asset_path
    assert_equal [ "--volume", "$(pwd)/.kamal/assets/volumes/app-web-12345:bar" ], config_with_assets.role(:web).asset_volume_args
    assert_nil config_with_assets.role(:workers).asset_volume_args
    assert config_with_assets.role(:web).assets?
    assert_not config_with_assets.role(:workers).assets?

  ensure
    ENV.delete("VERSION")
  end

  test "asset extracted path" do
    ENV["VERSION"] = "12345"
    assert_equal ".kamal/assets/extracted/app-web-12345", @config_with_roles.role(:web).asset_extracted_path
    assert_equal ".kamal/assets/extracted/app-workers-12345", @config_with_roles.role(:workers).asset_extracted_path
  ensure
    ENV.delete("VERSION")
  end

  test "asset volume path" do
    ENV["VERSION"] = "12345"
    assert_equal ".kamal/assets/volumes/app-web-12345", @config_with_roles.role(:web).asset_volume_path
    assert_equal ".kamal/assets/volumes/app-workers-12345", @config_with_roles.role(:workers).asset_volume_path
  ensure
    ENV.delete("VERSION")
  end
end
