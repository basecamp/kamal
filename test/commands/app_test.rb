require "test_helper"
require "mrsk/configuration"
require "mrsk/commands/app"

class CommandsAppTest < ActiveSupport::TestCase
  setup do
    ENV["RAILS_MASTER_KEY"] = "456"

    @config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ] }
    @app = Mrsk::Commands::App.new Mrsk::Configuration.new(@config)
  end

  teardown do
    ENV["RAILS_MASTER_KEY"] = nil
  end

  test "run" do
    assert_equal \
      [:docker, :run, "-d", "--restart unless-stopped", "--name", "app-missing", "-e", "RAILS_MASTER_KEY=456", "--label", "service=app", "--label", "role=web", "--label", "traefik.http.routers.app.rule='PathPrefix(`/`)'", "--label", "traefik.http.services.app.loadbalancer.healthcheck.path=/up", "--label", "traefik.http.services.app.loadbalancer.healthcheck.interval=1s", "--label", "traefik.http.middlewares.app.retry.attempts=3", "--label", "traefik.http.middlewares.app.retry.initialinterval=500ms", "dhh/app:missing"], @app.run
  end

  test "run with volumes" do
    @config[:volumes] = ["/local/path:/container/path" ]

    assert_equal \
      [:docker, :run, "-d", "--restart unless-stopped", "--name", "app-missing", "-e", "RAILS_MASTER_KEY=456", "--volume", "/local/path:/container/path", "--label", "service=app", "--label", "role=web", "--label", "traefik.http.routers.app.rule='PathPrefix(`/`)'", "--label", "traefik.http.services.app.loadbalancer.healthcheck.path=/up", "--label", "traefik.http.services.app.loadbalancer.healthcheck.interval=1s", "--label", "traefik.http.middlewares.app.retry.attempts=3", "--label", "traefik.http.middlewares.app.retry.initialinterval=500ms", "dhh/app:missing"], @app.run
  end

  test "run with logging driver" do
    @config[:logging] = { 'driver' => 'none' }

    assert_equal \
      [:docker, :run, "-d", "--restart unless-stopped", "--name", "app-missing", "-e", "RAILS_MASTER_KEY=456", "--log-driver", "none", "--label", "service=app", "--label", "role=web", "--label", "traefik.http.routers.app.rule='PathPrefix(`/`)'", "--label", "traefik.http.services.app.loadbalancer.healthcheck.path=/up", "--label", "traefik.http.services.app.loadbalancer.healthcheck.interval=1s", "--label", "traefik.http.middlewares.app.retry.attempts=3", "--label", "traefik.http.middlewares.app.retry.initialinterval=500ms", "dhh/app:missing"], @app.run
  end

  test "run with logging options" do
    @config[:logging] = { 'options' => { 'max-size' => '10m' } }

    assert_equal \
      [:docker, :run, "-d", "--restart unless-stopped", "--name", "app-missing", "-e", "RAILS_MASTER_KEY=456", "--log-opt", "max-size=10m", "--label", "service=app", "--label", "role=web", "--label", "traefik.http.routers.app.rule='PathPrefix(`/`)'", "--label", "traefik.http.services.app.loadbalancer.healthcheck.path=/up", "--label", "traefik.http.services.app.loadbalancer.healthcheck.interval=1s", "--label", "traefik.http.middlewares.app.retry.attempts=3", "--label", "traefik.http.middlewares.app.retry.initialinterval=500ms", "dhh/app:missing"], @app.run
  end

  test "run with" do
    assert_equal \
      [ :docker, :run, "--rm", "-e", "RAILS_MASTER_KEY=456", "dhh/app:missing", "bin/rails", "db:setup" ],
      @app.run_exec("bin/rails", "db:setup")
  end

  test "run without master key" do
    ENV["RAILS_MASTER_KEY"] = nil
    @app = Mrsk::Commands::App.new Mrsk::Configuration.new(@config.tap { |c| c[:skip_master_key] = true })

    assert @app.run.exclude?("RAILS_MASTER_KEY=456")
  end
end
