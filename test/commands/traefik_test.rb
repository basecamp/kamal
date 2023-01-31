require "test_helper"
require "mrsk/configuration"
require "mrsk/commands/traefik"

class CommandsTraefikTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }
  end

  test "run" do
    assert_equal \
      [:docker, :run, "--name traefik", "-d", "--restart unless-stopped", "-p 80:80", "-v /var/run/docker.sock:/var/run/docker.sock", "traefik", "--providers.docker", "--log.level=DEBUG", "--accesslog.format", "json", "--metrics.prometheus.buckets", "0.1,0.3,1.2,5.0"],
      new_command.run
  end

  private
    def new_command
      Mrsk::Commands::Traefik.new(Mrsk::Configuration.new(@config, version: "123"))
    end
end
