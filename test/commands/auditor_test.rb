require "test_helper"

class CommandsAuditorTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      audit_broadcast_cmd: "bin/audit_broadcast"
    }

    @auditor = new_command
  end

  test "record" do
    assert_equal [
      :echo,
      "[#{@auditor.details[:recorded_at]}]", "[#{@auditor.details[:performer]}]",
      "app removed container",
      ">>", "mrsk-app-audit.log"
    ], @auditor.record("app removed container")
  end

  test "record with destination" do
    new_command(destination: "staging").tap do |auditor|
      assert_equal [
        :echo,
        "[#{auditor.details[:recorded_at]}]", "[#{auditor.details[:performer]}]", "[#{auditor.details[:destination]}]",
        "app removed container",
        ">>", "mrsk-app-staging-audit.log"
      ], auditor.record("app removed container")
    end
  end

  test "record with command details" do
    new_command(role: "web").tap do |auditor|
      assert_equal [
        :echo,
        "[#{auditor.details[:recorded_at]}]", "[#{auditor.details[:performer]}]", "[#{auditor.details[:role]}]",
        "app removed container",
        ">>", "mrsk-app-audit.log"
      ], auditor.record("app removed container")
    end
  end

  test "record with arg details" do
    assert_equal [
      :echo,
      "[#{@auditor.details[:recorded_at]}]", "[#{@auditor.details[:performer]}]", "[value]",
      "app removed container",
      ">>", "mrsk-app-audit.log"
    ], @auditor.record("app removed container", detail: "value")
  end

  test "broadcast" do
    assert_equal [
      "bin/audit_broadcast",
      "'[#{@auditor.details[:performer]}] [value] app removed container'",
      env: {
        "MRSK_RECORDED_AT" => @auditor.details[:recorded_at],
        "MRSK_PERFORMER" => @auditor.details[:performer],
        "MRSK_EVENT" => "app removed container",
        "MRSK_DETAIL" => "value"
      }
    ], @auditor.broadcast("app removed container", detail: "value")
  end

  private
    def new_command(destination: nil, **details)
      Mrsk::Commands::Auditor.new(Mrsk::Configuration.new(@config, destination: destination, version: "123"), **details)
    end
end
