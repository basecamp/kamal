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
      assert_match "Running docker container stop traefik ; docker container prune --force --filter label=org.opencontainers.image.title=Traefik && docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik on 1.1.1.1", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.1", output
      assert_match "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/root/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE} on 1.1.1.1", output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target \"abcdefabcdef:80\" --deploy-timeout \"6s\" --buffer-requests --buffer-responses --log-request-header \"Cache-Control\" --log-request-header \"Last-Modified\" --log-request-header \"User-Agent\" on 1.1.1.1", output

      assert_match "docker container stop kamal-proxy on 1.1.1.2", output
      assert_match "Running docker container stop traefik ; docker container prune --force --filter label=org.opencontainers.image.title=Traefik && docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik on 1.1.1.2", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.2", output
      assert_match "docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --publish 80:80 --publish 443:443 --volume /var/run/docker.sock:/var/run/docker.sock --volume $(pwd)/.kamal/proxy/config:/root/.config/kamal-proxy --log-opt max-size=\"10m\" #{Kamal::Configuration::Proxy::DEFAULT_IMAGE} on 1.1.1.2", output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target \"abcdefabcdef:80\" --deploy-timeout \"6s\" --buffer-requests --buffer-responses --log-request-header \"Cache-Control\" --log-request-header \"Last-Modified\" --log-request-header \"User-Agent\" on 1.1.1.2", output
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
      .with(:docker, :logs, "proxy", " --tail 100", "--timestamps", "2>&1")
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
    run_command("remove").tap do |output|
      assert_match "/usr/bin/env ls .kamal/apps | wc -l", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "/usr/bin/env rm -r .kamal/proxy", output
    end
  end

  test "remove with other apps" do
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info).with(:ls, ".kamal/apps", "|", :wc, "-l").returns("1\n").twice

    run_command("remove").tap do |output|
      assert_match "Not removing the proxy, as other apps are installed, ignore this check with kamal proxy remove --force", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "force remove with other apps" do
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info).with(:ls, ".kamal/apps", "|", :wc, "-l").returns("1\n").twice

    run_command("remove").tap do |output|
      assert_match "Not removing the proxy, as other apps are installed, ignore this check with kamal proxy remove --force", output
    end
  ensure
    Thread.report_on_exception = true
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

  test "remove_host_directory" do
    run_command("remove_host_directory").tap do |output|
      assert_match "/usr/bin/env rm -r .kamal/proxy", output
    end
  end

  private
    def run_command(*command, fixture: :with_proxy)
      stdouted { Kamal::Cli::Proxy.start([ *command, "-c", "test/fixtures/deploy_#{fixture}.yml" ]) }
    end
end
