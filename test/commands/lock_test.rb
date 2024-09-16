require "test_helper"

class CommandsLockTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      builder: { "arch" => "amd64" }
    }
  end

  test "status" do
    assert_equal \
      "stat .kamal/lock-app-production > /dev/null && cat .kamal/lock-app-production/details | base64 -d",
      new_command.status.join(" ")
  end

  test "acquire" do
    assert_match \
      %r{mkdir \.kamal/lock-app-production && echo ".*" > \.kamal/lock-app-production/details}m,
      new_command.acquire("Hello", "123").join(" ")
  end

  test "release" do
    assert_match \
      "rm .kamal/lock-app-production/details && rm -r .kamal/lock-app-production",
      new_command.release.join(" ")
  end

  private
    def new_command
      Kamal::Commands::Lock.new(Kamal::Configuration.new(@config, version: "123", destination: "production"))
    end
end
