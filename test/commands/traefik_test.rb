require "test_helper"

class CommandsTraefikTest < ActiveSupport::TestCase
  setup do
    @image = "traefik:test"

    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      traefik: { "image" => @image, "args" => { "accesslog.format" => "json", "api.insecure" => true, "metrics.prometheus.buckets" => "0.1,0.3,1.2,5.0" } }
    }

    ENV["EXAMPLE_API_KEY"] = "456"
  end

  teardown do
    ENV.delete("EXAMPLE_API_KEY")
  end

  test "run" do
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")

    @config[:traefik]["host_port"] = "8080"
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 8080:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")

    @config[:traefik]["publish"] = false
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")
  end

  test "run with ports configured" do
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")

    @config[:traefik]["options"] = { "publish" => %w[9000:9000 9001:9001] }
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" --publish \"9000:9000\" --publish \"9001:9001\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")
  end

  test "run with volumes configured" do
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")

    @config[:traefik]["options"] = { "volume" => %w[./letsencrypt/acme.json:/letsencrypt/acme.json] }
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" --volume \"./letsencrypt/acme.json:/letsencrypt/acme.json\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")
  end

  test "run with several options configured" do
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")

    @config[:traefik]["options"] = { "volume" => %w[./letsencrypt/acme.json:/letsencrypt/acme.json], "publish" => %w[8080:8080], "memory" => "512m" }
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" --volume \"./letsencrypt/acme.json:/letsencrypt/acme.json\" --publish \"8080:8080\" --memory \"512m\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")
  end

  test "run with labels configured" do
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")

    @config[:traefik]["labels"] = { "traefik.http.routers.dashboard.service" => "api@internal", "traefik.http.routers.dashboard.middlewares" => "auth" }
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" --label traefik.http.routers.dashboard.service=\"api@internal\" --label traefik.http.routers.dashboard.middlewares=\"auth\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")
  end

  test "run with env configured" do
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")

    @config[:traefik]["env"] = { "secret" => %w[EXAMPLE_API_KEY] }
    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")
  end

  test "run without configuration" do
    @config.delete(:traefik)

    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{Kamal::Commands::Traefik::DEFAULT_IMAGE} --providers.docker --log.level=\"DEBUG\"",
      new_command.run.join(" ")
  end

  test "run with logging config" do
    @config[:logging] = { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => "3" } }

    assert_equal \
      "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-driver \"local\" --log-opt max-size=\"100m\" --log-opt max-file=\"3\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"DEBUG\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
      new_command.run.join(" ")
  end

  test "run with default args overriden" do
    @config[:traefik]["args"]["log.level"] = "ERROR"

    assert_equal \
    "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{@image} --providers.docker --log.level=\"ERROR\" --accesslog.format=\"json\" --api.insecure --metrics.prometheus.buckets=\"0.1,0.3,1.2,5.0\"",
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
      "docker ps --filter name=^traefik$",
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
      new_command.logs(since: "2h").join(" ")
  end

  test "traefik logs last 10 lines" do
    assert_equal \
      "docker logs traefik  --tail 10 --timestamps 2>&1",
      new_command.logs(lines: 10).join(" ")
  end

  test "traefik logs with grep hello!" do
    assert_equal \
      "docker logs traefik --timestamps 2>&1 | grep 'hello!'",
      new_command.logs(grep: "hello!").join(" ")
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
      "ssh -t root@1.1.1.1 -p 22 'docker logs traefik --timestamps --tail 10 --follow 2>&1'",
      new_command.follow_logs(host: @config[:servers].first)
  end

  test "traefik follow logs with grep hello!" do
    assert_equal \
      "ssh -t root@1.1.1.1 -p 22 'docker logs traefik --timestamps --tail 10 --follow 2>&1 | grep \"hello!\"'",
      new_command.follow_logs(host: @config[:servers].first, grep: "hello!")
  end

  test "secrets io" do
    @config[:traefik]["env"] = { "secret" => %w[EXAMPLE_API_KEY] }

    assert_equal "EXAMPLE_API_KEY=456\n", new_command.env.secrets_io.string
  end

  test "make_env_directory" do
    assert_equal "mkdir -p .kamal/env/traefik", new_command.make_env_directory.join(" ")
  end

  test "remove_env_file" do
    assert_equal "rm -f .kamal/env/traefik/traefik.env", new_command.remove_env_file.join(" ")
  end

  private
    def new_command
      Kamal::Commands::Traefik.new(Kamal::Configuration.new(@config, version: "123"))
    end
end
