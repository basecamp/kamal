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

  test "broadcast" do
    assert_match \
      /echo '.* app removed container' \| bin\/audit_broadcast/,
      new_command.broadcast("app removed container").join(" ")
  end

  private
    def new_command
      Mrsk::Commands::Auditor.new(Mrsk::Configuration.new(@config, version: "123"))
    end
end
