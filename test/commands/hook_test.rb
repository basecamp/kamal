require "test_helper"

class CommandsHookTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    freeze_time

    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }

    @performer = Kamal::Git.email.presence || `whoami`.chomp
    @recorded_at = Time.now.utc.iso8601
  end

  test "run" do
    assert_equal [
      ".kamal/hooks/foo",
      { env: {
        "KAMAL_RECORDED_AT" => @recorded_at,
        "KAMAL_PERFORMER" => @performer,
        "KAMAL_VERSION" => "123",
        "KAMAL_SERVICE_VERSION" => "app@123",
        "KAMAL_SERVICE" => "app" } }
    ], new_command.run("foo")
  end

  test "run with custom hooks_path" do
    ENV["KAMAL_HOOKS_PATH"] = "custom/hooks/path"
    assert_equal [
      "custom/hooks/path/foo",
      { env: {
        "KAMAL_RECORDED_AT" => @recorded_at,
        "KAMAL_PERFORMER" => @performer,
        "KAMAL_VERSION" => "123",
        "KAMAL_SERVICE_VERSION" => "app@123",
        "KAMAL_SERVICE" => "app" } }
    ], new_command.run("foo")
  ensure
    ENV.delete("KAMAL_HOOKS_PATH")
  end

  private
    def new_command(**extra_config)
      Kamal::Commands::Hook.new(Kamal::Configuration.new(@config.merge(**extra_config), version: "123"))
    end
end
