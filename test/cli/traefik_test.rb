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

  test "downgrade" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678")

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678")

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with { |*args| args[0..1] == [ :sh, "-c" ] }
      .returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running") # health check

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # workers health check

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :inspect, "-f '{{ range .Mounts }}{{printf \"%s %s\\n\" .Source .Destination}}{{ end }}'", "app-web-123", "|", :awk, "'$2 == \"/tmp/kamal-cord\" {print $1}'", raise_on_non_zero_exit: false)
      .returns("") # old version

    run_command("downgrade", "-y").tap do |output|
      assert_match "Downgrading to Traefik on 1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4...", output
      assert_match "docker login -u [REDACTED] -p [REDACTED]", output
      assert_match "docker container stop kamal-proxy ; docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy && docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "docker container stop traefik", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=Traefik", output
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match "docker login -u [REDACTED] -p [REDACTED]", output
      assert_match "docker container start traefik || docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" traefik:v2.10 --providers.docker --log.level=\"DEBUG\"", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match %r{docker rename app-web-latest app-web-latest_replaced_.*}, output
      assert_match %r{docker run --detach --restart unless-stopped --name app-web-latest --hostname 1.1.1.1-.* -e KAMAL_CONTAINER_NAME="app-web-latest" -e KAMAL_VERSION="latest" --env-file .kamal/env/roles/app-web.env --health-cmd}, output
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match "docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +6 | while read container_id; do docker rm $container_id; done", output
      assert_match "docker image prune --force --filter label=service=app", output
      assert_match "Downgraded to Traefik on 1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4", output
    end
  end

  test "downgrade rolling" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678")

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678")

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with { |*args| args[0..1] == [ :sh, "-c" ] }
      .returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running") # health check

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # workers health check

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :inspect, "-f '{{ range .Mounts }}{{printf \"%s %s\\n\" .Source .Destination}}{{ end }}'", "app-web-123", "|", :awk, "'$2 == \"/tmp/kamal-cord\" {print $1}'", raise_on_non_zero_exit: false)
      .returns("") # old version

    run_command("downgrade", "--rolling", "-y",).tap do |output|
      %w[1.1.1.1 1.1.1.2 1.1.1.3 1.1.1.4].each do |host|
        assert_match "Downgrading to Traefik on #{host}...", output
        assert_match "docker container stop kamal-proxy ; docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy && docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
        assert_match "Downgraded to Traefik on #{host}", output
      end
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Traefik.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
