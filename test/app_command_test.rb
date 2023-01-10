require "test_helper"
require "mrsk/configuration"
require "mrsk/commands"

ENV["VERSION"] = "123"
ENV["RAILS_MASTER_KEY"] = "456"

class AppCommandTest < ActiveSupport::TestCase
  setup do
    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ] }
    @app = Mrsk::Commands::App.new Mrsk::Configuration.new(@config)
  end

  test "run" do
    assert_equal \
      [:docker, :run, "-d", "--restart unless-stopped", "--name", "app-123", "-e", "RAILS_MASTER_KEY=456", "--label", "service=app", "--label", "role=web", "--label", "traefik.http.routers.app.rule='PathPrefix(`/`)'", "--label", "traefik.http.services.app.loadbalancer.healthcheck.path=/up", "--label", "traefik.http.services.app.loadbalancer.healthcheck.interval=1s", "--label", "traefik.http.middlewares.app.retry.attempts=3", "--label", "traefik.http.middlewares.app.retry.initialinterval=500ms", "dhh/app:123"], @app.run
  end
end
