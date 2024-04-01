require "test_helper"

class CommandsLockTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }
  end

  test "status" do
    assert_equal \
      "stat .kamal/locks/app-production > /dev/null && cat .kamal/locks/app-production/details | base64 -d",
      new_command.status.join(" ")
  end

  test "acquire" do
    assert_match \
      %r{mkdir \.kamal/locks/app-production && echo ".*" > \.kamal/locks/app-production/details}m,
      new_command.acquire("Hello", "123").join(" ")
  end

  test "release" do
    assert_match \
      "rm .kamal/locks/app-production/details && rm -r .kamal/locks/app-production",
      new_command.release.join(" ")
  end

  private
    def new_command
      Kamal::Commands::Lock.new(Kamal::Configuration.new(@config, version: "123", destination: "production"))
    end
end
