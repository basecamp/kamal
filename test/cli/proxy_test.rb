require_relative "cli_test_case"

class CliProxyTest < CliTestCase
  test "boot" do
    run_command("boot").tap do |output|
      assert_match "docker login", output
      assert_match "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/root/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE}", output
    end
  end

  test "reboot" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet")
      .returns("abcdefabcdef")
      .at_least_once

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with { |*args| args[0..1] == [ :sh, "-c" ] }
      .returns("123")
      .at_least_once

    run_command("reboot", "-y").tap do |output|
      assert_match "docker container stop kamal-proxy on 1.1.1.1", output
      assert_match "docker container stop traefik on 1.1.1.1", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.1", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=Traefik on 1.1.1.1", output
      assert_match "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/root/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE} on 1.1.1.1", output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target \"abcdefabcdef:80\" --deploy-timeout \"6s\" --buffer-requests --buffer-responses --log-request-header \"Cache-Control\" --log-request-header \"Last-Modified\" on 1.1.1.1", output

      assert_match "docker container stop kamal-proxy on 1.1.1.2", output
      assert_match "docker container stop traefik on 1.1.1.2", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.2", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=Traefik on 1.1.1.2", output
      assert_match "docker run --name traefik --detach --restart unless-stopped --publish 80:80 --volume /var/run/docker.sock:/var/run/docker.sock --env-file .kamal/env/traefik/traefik.env --log-opt max-size=\"10m\" --label traefik.http.routers.catchall.entryPoints=\"http\" --label traefik.http.routers.catchall.rule=\"PathPrefix(\\`/\\`)\" --label traefik.http.routers.catchall.service=\"unavailable\" --label traefik.http.routers.catchall.priority=\"1\" --label traefik.http.services.unavailable.loadbalancer.server.port=\"0\" traefik:v2.10 --providers.docker --log.level=\"DEBUG\" on 1.1.1.2", output
    end
  end

  test "reboot --rolling" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet")
      .returns("abcdefabcdef")
      .at_least_once

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with { |*args| args[0..1] == [ :sh, "-c" ] }
      .returns("123")
      .at_least_once

    run_command("reboot", "--rolling", "-y").tap do |output|
      assert_match "Running docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.1", output
    end
  end

  test "start" do
    run_command("start").tap do |output|
      assert_match "docker container start kamal-proxy", output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match "docker container stop kamal-proxy", output
    end
  end

  test "restart" do
    Kamal::Cli::Proxy.any_instance.expects(:stop)
    Kamal::Cli::Proxy.any_instance.expects(:start)

    run_command("restart")
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match "docker ps --filter name=^kamal-proxy$", output
    end
  end

  test "logs" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :logs, "kamal-proxy", " --tail 100", "--timestamps", "2>&1")
      .returns("Log entry")

    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :logs, "traefik", " --tail 100", "--timestamps", "2>&1")
      .returns("Log entry")

    run_command("logs").tap do |output|
      assert_match "Proxy Host: 1.1.1.1", output
      assert_match "Log entry", output
    end
  end

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker logs kamal-proxy --timestamps --tail 10 --follow 2>&1'")

    assert_match "docker logs kamal-proxy --timestamps --tail 10 --follow", run_command("logs", "--follow")
  end

  test "remove" do
    Kamal::Cli::Proxy.any_instance.expects(:stop)
    Kamal::Cli::Proxy.any_instance.expects(:remove_container)
    Kamal::Cli::Proxy.any_instance.expects(:remove_image)

    run_command("remove")
  end

  test "remove_container" do
    run_command("remove_container").tap do |output|
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy", output
    end
  end

  test "remove_image" do
    run_command("remove_image").tap do |output|
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
    end
  end

  test "commands disallowed when proxy is disabled" do
    assert_raises_when_disabled "boot"
    assert_raises_when_disabled "reboot"
    assert_raises_when_disabled "start"
    assert_raises_when_disabled "stop"
    assert_raises_when_disabled "details"
    assert_raises_when_disabled "logs"
    assert_raises_when_disabled "remove"
  end

  private
    def run_command(*command, fixture: :with_proxy)
      stdouted { Kamal::Cli::Proxy.start([ *command, "-c", "test/fixtures/deploy_#{fixture}.yml" ]) }
    end

    def assert_raises_when_disabled(command)
      assert_raises "kamal proxy commands are disabled unless experimental proxy support is enabled. Use `kamal traefik` commands instead." do
        run_command(command, fixture: :with_accessories)
      end
    end
end
