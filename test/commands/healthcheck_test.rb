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
      "docker run --detach --name healthcheck-app-123 --publish 3999:3000 --label service=healthcheck-app -e MRSK_CONTAINER_NAME=\"healthcheck-app\" dhh/app:123",
      new_command.run.join(" ")
  end

  test "run with custom port" do
    @config[:healthcheck] = { "port" => 3001 }

    assert_equal \
      "docker run --detach --name healthcheck-app-123 --publish 3999:3001 --label service=healthcheck-app -e MRSK_CONTAINER_NAME=\"healthcheck-app\" dhh/app:123",
      new_command.run.join(" ")
  end

  test "run with destination" do
    @destination = "staging"

    assert_equal \
      "docker run --detach --name healthcheck-app-staging-123 --publish 3999:3000 --label service=healthcheck-app-staging -e MRSK_CONTAINER_NAME=\"healthcheck-app-staging\" dhh/app:123",
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

  test "stop with destination" do
    @destination = "staging"

    assert_equal \
      "docker container ls --all --filter name=healthcheck-app-staging --quiet | xargs docker stop",
      new_command.stop.join(" ")
  end

  test "remove" do
    assert_equal \
      "docker container ls --all --filter name=healthcheck-app --quiet | xargs docker container rm",
      new_command.remove.join(" ")
  end

  test "remove with destination" do
    @destination = "staging"

    assert_equal \
      "docker container ls --all --filter name=healthcheck-app-staging --quiet | xargs docker container rm",
      new_command.remove.join(" ")
  end

  test "logs" do
    assert_equal \
      "docker container ls --all --filter name=healthcheck-app --quiet | xargs docker logs --tail 50 2>&1",
      new_command.logs.join(" ")
  end

  test "logs with destination" do
    @destination = "staging"

    assert_equal \
      "docker container ls --all --filter name=healthcheck-app-staging --quiet | xargs docker logs --tail 50 2>&1",
      new_command.logs.join(" ")
  end

  private
    def new_command
      Mrsk::Commands::Healthcheck.new(Mrsk::Configuration.new(@config, destination: @destination, version: "123"))
    end
end
