require "test_helper"

class CommandsPruneTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }
  end

  test "images" do
    assert_equal \
      "docker image prune --all --force --filter label=service=app --filter dangling=true",
      new_command.images.join(" ")
  end

  test "containers" do
    assert_equal \
      "docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +6 | while read container_id; do docker rm $container_id; done",
      new_command.containers.join(" ")
  end

  private
    def new_command
      Mrsk::Commands::Prune.new(Mrsk::Configuration.new(@config, version: "123"))
    end
end
