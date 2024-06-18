require_relative "cli_test_case"

class CliTraefikTest < CliTestCase
  test "boot" do
    run_command("boot").tap do |output|
      assert_match "docker login", output
      assert_match "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{Kamal::Configuration::Traefik::DEFAULT_IMAGE} --providers.docker --log.level=\"DEBUG\"", output
    end
  end

  test "reboot" do
    Kamal::Commands::Registry.any_instance.expects(:login).twice

    run_command("reboot", "-y").tap do |output|
      assert_match "docker container stop traefik", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=Traefik", output
      assert_match "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" #{Kamal::Configuration::Traefik::DEFAULT_IMAGE} --providers.docker --log.level=\"DEBUG\"", output
    end
  end

  test "reboot --rolling" do
    Object.any_instance.stubs(:sleep)

    run_command("reboot", "--rolling", "-y").tap do |output|
      assert_match "Running docker container prune --force --filter label=org.opencontainers.image.title=Traefik on 1.1.1.1", output
    end
  end

  test "start" do
    run_command("start").tap do |output|
      assert_match "docker container start traefik", output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match "docker container stop traefik", output
    end
  end

  test "restart" do
    Kamal::Cli::Traefik.any_instance.expects(:stop)
    Kamal::Cli::Traefik.any_instance.expects(:start)

    run_command("restart")
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match "docker ps --filter name=^traefik$", output
    end
  end

  test "logs" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :logs, "traefik", " --tail 100", "--timestamps", "2>&1")
      .returns("Log entry")

    run_command("logs").tap do |output|
      assert_match "Traefik Host: 1.1.1.1", output
      assert_match "Log entry", output
    end
  end

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker logs traefik --timestamps --tail 10 --follow 2>&1'")

    assert_match "docker logs traefik --timestamps --tail 10 --follow", run_command("logs", "--follow")
  end

  test "logs with follow and grep" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker logs traefik --timestamps --tail 10 --follow 2>&1 | grep \"hey\"'")

    assert_match "docker logs traefik --timestamps --tail 10 --follow 2>&1 | grep \"hey\"", run_command("logs", "--follow", "--grep", "hey")
  end

  test "logs with follow, grep, and grep options" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker logs traefik --timestamps --tail 10 --follow 2>&1 | grep \"hey\" -C 2'")

    assert_match "docker logs traefik --timestamps --tail 10 --follow 2>&1 | grep \"hey\" -C 2", run_command("logs", "--follow", "--grep", "hey", "--grep-options", "-C 2")
  end

  test "remove" do
    Kamal::Cli::Traefik.any_instance.expects(:stop)
    Kamal::Cli::Traefik.any_instance.expects(:remove_container)
    Kamal::Cli::Traefik.any_instance.expects(:remove_image)

    run_command("remove")
  end

  test "remove_container" do
    run_command("remove_container").tap do |output|
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=Traefik", output
    end
  end

  test "remove_image" do
    run_command("remove_image").tap do |output|
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik", output
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Traefik.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
