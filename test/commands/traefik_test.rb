require "test_helper"

class CommandsTraefikTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "args" => { "accesslog.format" => "json", "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }
  end

  test "run" do
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --log-opt max-size=10m --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock traefik --providers.docker --log.level=DEBUG --accesslog.format json --metrics.prometheus.buckets 0.1,0.3,1.2,5.0",
      new_command.run.join(" ")

    @config[:traefik]["host_port"] = 8080
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --log-opt max-size=10m --publish 8080:80 --volume /var/run/docker.sock:/var/run/docker.sock traefik --providers.docker --log.level=DEBUG --accesslog.format json --metrics.prometheus.buckets 0.1,0.3,1.2,5.0",
      new_command.run.join(" ")
  end

  test "traefik start" do
    assert_equal \
      "docker container start traefik",
      new_command.start.join(" ")
  end

  test "traefik stop" do
    assert_equal \
      "docker container stop traefik",
      new_command.stop.join(" ")
  end

  test "traefik info" do
    assert_equal \
      "docker ps --filter name=traefik",
      new_command.info.join(" ")
  end

  test "traefik logs" do
    assert_equal \
      "docker logs traefik --timestamps 2>&1",
      new_command.logs.join(" ")
  end

  test "traefik logs since 2h" do
    assert_equal \
      "docker logs traefik  --since 2h --timestamps 2>&1",
      new_command.logs(since: '2h').join(" ")
  end

  test "traefik logs last 10 lines" do
    assert_equal \
      "docker logs traefik  --tail 10 --timestamps 2>&1",
      new_command.logs(lines: 10).join(" ")
  end

  test "traefik logs with grep hello!" do
    assert_equal \
      "docker logs traefik --timestamps 2>&1 | grep 'hello!'",
      new_command.logs(grep: 'hello!').join(" ")
  end

  test "traefik remove container" do
    assert_equal \
      "docker container prune --force --filter label=org.opencontainers.image.title=Traefik",
      new_command.remove_container.join(" ")
  end

  test "traefik remove image" do
    assert_equal \
      "docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik",
      new_command.remove_image.join(" ")
  end

  test "traefik follow logs" do
    assert_equal \
      "ssh -t root@1.1.1.1 'docker logs traefik --timestamps --tail 10 --follow 2>&1'",
      new_command.follow_logs(host: @config[:servers].first)
  end

  test "traefik follow logs with grep hello!" do
    assert_equal \
      "ssh -t root@1.1.1.1 'docker logs traefik --timestamps --tail 10 --follow 2>&1 | grep \"hello!\"'",
      new_command.follow_logs(host: @config[:servers].first, grep: 'hello!')
  end

  private
    def new_command
      Mrsk::Commands::Traefik.new(Mrsk::Configuration.new(@config, version: "123"))
    end
end
