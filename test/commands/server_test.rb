require "test_helper"

class CommandsServerTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      builder: { "arch" => "amd64" }, traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }
  end

  test "ensure run directory" do
    assert_equal "mkdir -p .kamal", new_command.ensure_run_directory.join(" ")
  end

  test "ensure non default run directory" do
    assert_equal "mkdir -p /var/run/kamal", new_command(run_directory: "/var/run/kamal").ensure_run_directory.join(" ")
  end

  private
    def new_command(extra_config = {})
      Kamal::Commands::Server.new(Kamal::Configuration.new(@config.merge(extra_config)))
    end
end
