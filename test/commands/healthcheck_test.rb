require "test_helper"

class CommandsHealthcheckTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }
  end

  test "run" do
    assert_equal \
      "docker run --detach --name healthcheck-app-123 --publish 3999:3000 --label service=healthcheck-app dhh/app:123",
      new_command.run.join(" ")
  end

  test "run with custom port" do
    @config[:healthcheck] = { "port" => 3001 }

    assert_equal \
      "docker run --detach --name healthcheck-app-123 --publish 3999:3001 --label service=healthcheck-app dhh/app:123",
      new_command.run.join(" ")
  end

  test "curl" do
    assert_equal \
      "curl --silent --output /dev/null --write-out '%{http_code}' --max-time 2 http://localhost:3999/up",
      new_command.curl.join(" ")
  end

  test "curl with custom path" do
    @config[:healthcheck] = { "path" => "/healthz" }

    assert_equal \
      "curl --silent --output /dev/null --write-out '%{http_code}' --max-time 2 http://localhost:3999/healthz",
      new_command.curl.join(" ")
  end

  test "stop" do
    assert_equal \
      "docker container ls --all --filter name=healthcheck-app --quiet | xargs docker stop",
      new_command.stop.join(" ")
  end

  test "remove" do
    assert_equal \
      "docker container ls --all --filter name=healthcheck-app --quiet | xargs docker container rm",
      new_command.remove.join(" ")
  end

  private
    def new_command
      Mrsk::Commands::Healthcheck.new(Mrsk::Configuration.new(@config, version: "123"))
    end
end
