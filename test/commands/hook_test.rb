require "test_helper"

class CommandsHookTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    freeze_time

    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      builder: { "arch" => "amd64" }
    }

    @performer = Kamal::Git.email.presence || `whoami`.chomp
    @recorded_at = Time.now.utc.iso8601
  end

  test "run" do
    assert_equal [ ".kamal/hooks/foo" ], new_command.run("foo")
  end

  test "env" do
    assert_equal ({
      "KAMAL_RECORDED_AT" => @recorded_at,
      "KAMAL_PERFORMER" => @performer,
      "KAMAL_VERSION" => "123",
      "KAMAL_SERVICE_VERSION" => "app@123",
      "KAMAL_SERVICE" => "app"
    }), new_command.env
  end

  test "run with custom hooks_path" do
    assert_equal [ "custom/hooks/path/foo" ], new_command(hooks_path: "custom/hooks/path").run("foo")
  end

  test "env with secrets" do
    with_test_secrets("secrets" => "DB_PASSWORD=secret") do
      assert_equal (
        {
          "KAMAL_RECORDED_AT" => @recorded_at,
          "KAMAL_PERFORMER" => @performer,
          "KAMAL_VERSION" => "123",
          "KAMAL_SERVICE_VERSION" => "app@123",
          "KAMAL_SERVICE" => "app",
          "DB_PASSWORD" => "secret" }
      ), new_command.env(secrets: true)
    end
  end

  test "env with hook_outputs" do
    assert_equal ({
      "KAMAL_RECORDED_AT" => @recorded_at,
      "KAMAL_PERFORMER" => @performer,
      "KAMAL_VERSION" => "123",
      "KAMAL_SERVICE_VERSION" => "app@123",
      "KAMAL_SERVICE" => "app",
      "DEPLOY_ID" => "abc123"
    }), new_command.env(hook_outputs: { "DEPLOY_ID" => "abc123" })
  end

  test "hook_outputs cannot override tags" do
    env = new_command.env(hook_outputs: { "KAMAL_VERSION" => "overridden" })
    assert_equal "123", env["KAMAL_VERSION"]
  end

  test "hook_outputs cannot override secrets" do
    with_test_secrets("secrets" => "DB_PASSWORD=secret") do
      env = new_command.env(secrets: true, hook_outputs: { "DB_PASSWORD" => "overridden" })
      assert_equal "secret", env["DB_PASSWORD"]
    end
  end

  private
    def new_command(**extra_config)
      Kamal::Commands::Hook.new(Kamal::Configuration.new(@config.merge(**extra_config), version: "123"))
    end
end
