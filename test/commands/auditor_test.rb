require "test_helper"

class CommandsAuditorTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      audit_broadcast_cmd: "bin/audit_broadcast"
    }
  end

  test "record" do
    assert_match \
      /echo '.* app removed container' >> mrsk-app-audit.log/,
      new_command.record("app removed container").join(" ")
  end

  test "record with destination" do
    @destination = "staging"

    assert_match \
      /echo '.* app removed container' >> mrsk-app-staging-audit.log/,
      new_command.record("app removed container").join(" ")
  end

  test "record with role" do
    @role = "web"

    assert_match \
      /echo '.* \[web\] app removed container' >> mrsk-app-audit.log/,
      new_command.record("app removed container").join(" ")
  end

  test "broadcast" do
    assert_match \
      /bin\/audit_broadcast '\[.*\] app removed container'/,
      new_command.broadcast("app removed container").join(" ")
  end

  private
    def new_command
      Mrsk::Commands::Auditor.new(Mrsk::Configuration.new(@config, destination: @destination, version: "123"), role: @role)
    end
end
