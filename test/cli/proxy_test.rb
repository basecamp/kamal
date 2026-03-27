require_relative "cli_test_case"

class CliProxyTest < CliTestCase
  test "boot" do
    run_command("boot").tap do |output|
      assert_match "docker login", output
      assert_match "mkdir -p .kamal/proxy/apps-config", output
      assert_match "echo $(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\") | xargs docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy", output
    end
  end

  test "boot with run config" do
    run_command("boot", fixture: :with_proxy_run_config).tap do |output|
      assert_match "docker login", output
      assert_match "mkdir -p .kamal/proxy/apps-config", output
      assert_match "docker container start kamal-proxy || docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 80:80 --publish 443:443 --log-opt max-size=10m --expose=9090 --cpus \"1.5\" registry:4443/basecamp/kamal-proxy:v0.9.2 kamal-proxy run --debug --metrics-port \"9090\" on 1.1.1.1", output
      assert_match "docker container start kamal-proxy || docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config --publish 80:80 --publish 443:443 --log-opt max-size=10m --expose=9190 basecamp/kamal-proxy:v0.9.2 kamal-proxy run --metrics-port \"9190\" on 1.1.1.3", output
    end
  end

  test "boot with run config conflicts" do
    assert_raises Kamal::ConfigurationError, "Conflicting proxy run configurations for host 1.1.1.2" do
      run_command("boot", fixture: :with_proxy_run_config_conflicts)
    end
  end

  test "boot old version" do
    Thread.report_on_exception = false
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "kamal-proxy", "--format '{{.Config.Image}}'", "|", :awk, "-F:", "'{print $NF}'")
      .returns("v0.0.1")
      .at_least_once

    exception = assert_raises do
      run_command("boot").tap do |output|
        assert_match "docker login", output
        assert_match "echo $(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\") | xargs docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy", output
      end
    end

    assert_includes exception.message, "kamal-proxy version v0.0.1 is too old, run `kamal proxy reboot` in order to update to at least #{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}"
  ensure
    Thread.report_on_exception = false
  end

  test "boot correct version" do
    Thread.report_on_exception = false
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "kamal-proxy", "--format '{{.Config.Image}}'", "|", :awk, "-F:", "'{print $NF}'")
      .returns(Kamal::Configuration::Proxy::Run::MINIMUM_VERSION)
      .at_least_once

    run_command("boot").tap do |output|
      assert_match "docker login", output
      assert_match "docker container start kamal-proxy || echo $(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\") | xargs docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy", output
    end
  ensure
    Thread.report_on_exception = false
  end

  test "reboot" do
    run_command("reboot", "-y").tap do |output|
      assert_match "docker container stop kamal-proxy on 1.1.1.1", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.1", output
      assert_match "mkdir -p .kamal/proxy/apps-config on 1.1.1.1", output
      assert_match "echo $(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\") | xargs docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config on 1.1.1.1", output

      assert_match "docker container stop kamal-proxy on 1.1.1.2", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy on 1.1.1.2", output
      assert_match "mkdir -p .kamal/proxy/apps-config on 1.1.1.1", output
      assert_match "echo $(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\") | xargs docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy --volume $PWD/.kamal/proxy/apps-config:/home/kamal-proxy/.apps-config on 1.1.1.2", output
    end
  end

  test "reboot --rolling" do
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
      assert_match "docker ps --filter 'name=^kamal-proxy$'", output
    end
  end

  test "logs" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :logs, "kamal-proxy", "--tail 100", "--timestamps", "2>&1")
      .returns("Log entry")

    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :logs, "proxy", "--tail 100", "--timestamps", "2>&1")
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

  test "upgrade" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("12345678")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "kamal-proxy", "--format '{{.Config.Image}}'", "|", :awk, "-F:", "'{print $NF}'")
      .returns(Kamal::Configuration::Proxy::Run::MINIMUM_VERSION)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-workers-latest$'", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # workers health check

    run_command("upgrade", "-y").tap do |output|
      assert_match "Upgrading proxy on 1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4...", output
      assert_match "docker login -u [REDACTED] -p [REDACTED]", output
      assert_match "docker container stop traefik ; docker container prune --force --filter label=org.opencontainers.image.title=Traefik && docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik", output
      assert_match "docker container stop kamal-proxy", output
      assert_match "docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match "docker network create kamal", output
      assert_match "docker login -u [REDACTED] -p [REDACTED]", output
      assert_match "docker container start kamal-proxy || echo $(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\") | xargs docker run --name kamal-proxy --network kamal --detach --restart unless-stopped --volume kamal-proxy-config:/home/kamal-proxy/.config/kamal-proxy", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match %r{docker rename app-web-latest app-web-latest_replaced_.*}, output
      assert_match "/usr/bin/env mkdir -p .kamal/apps/app/env/roles", output
      assert_match "Uploading \"\\n\" to .kamal/apps/app/env/roles/web.env", output
      assert_match %r{docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-.* --env KAMAL_CONTAINER_NAME="app-web-latest" --env KAMAL_VERSION="latest" --env KAMAL_HOST="1.1.1.1" --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size="10m" --label service="app" --label role="web" --label destination dhh/app:latest}, output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target=\"12345678:80\" --deploy-timeout=\"6s\" --drain-timeout=\"30s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"", output
      assert_match "docker container ls --all --filter 'name=^app-web-12345678$' --quiet | xargs docker stop", output
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match "/usr/bin/env mkdir -p .kamal", output
      assert_match "docker ps -q -a --filter label=service=app --filter status=created --filter status=exited --filter status=dead | tail -n +6 | while read container_id; do docker rm $container_id; done", output
      assert_match "docker image prune --force --filter label=service=app", output
      assert_match "Upgraded proxy on 1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4", output
    end
  end

  test "upgrade rolling" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("12345678")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "kamal-proxy", "--format '{{.Config.Image}}'", "|", :awk, "-F:", "'{print $NF}'")
      .returns(Kamal::Configuration::Proxy::Run::MINIMUM_VERSION)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-workers-latest$'", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # workers health check

    run_command("upgrade", "--rolling", "-y",).tap do |output|
      %w[1.1.1.1 1.1.1.2 1.1.1.3 1.1.1.4].each do |host|
        assert_match "Upgrading proxy on #{host}...", output
        assert_match "docker container stop traefik ; docker container prune --force --filter label=org.opencontainers.image.title=Traefik && docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik on #{host}", output
        assert_match "Upgraded proxy on #{host}", output
      end
    end
  end

  test "boot_config set" do
    run_command("boot_config", "set").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/options on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image_version on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set no publish" do
    run_command("boot_config", "set", "--publish", "false").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Uploading \"--log-opt max-size=10m\" to .kamal/proxy/options on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image_version on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set custom max_size" do
    run_command("boot_config", "set", "--log-max-size", "100m").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Uploading \"--publish 80:80 --publish 443:443 --log-opt max-size=100m\" to .kamal/proxy/options on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image_version on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set no log max size" do
    run_command("boot_config", "set", "--log-max-size=").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Uploading \"--publish 80:80 --publish 443:443\" to .kamal/proxy/options on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image_version on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set custom ports" do
    run_command("boot_config", "set", "--http-port", "8080", "--https-port", "8443").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Uploading \"--publish 8080:80 --publish 8443:443 --log-opt max-size=10m\" to .kamal/proxy/options on #{host}", output
      end
    end
  end

  test "boot_config set bind IP" do
    run_command("boot_config", "set", "--publish-host-ip", "127.0.0.1").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Uploading \"--publish 127.0.0.1:80:80 --publish 127.0.0.1:443:443 --log-opt max-size=10m\" to .kamal/proxy/options on #{host}", output
      end
    end
  end

  test "boot_config set multiple bind IPs" do
    run_command("boot_config", "set", "--publish-host-ip", "127.0.0.1", "--publish-host-ip", "::1").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Uploading \"--publish 127.0.0.1:80:80 --publish 127.0.0.1:443:443 --publish [::1]:80:80 --publish [::1]:443:443 --log-opt max-size=10m\" to .kamal/proxy/options on #{host}", output
      end
    end
  end

  test "boot_config set invalid bind IPs" do
    exception = assert_raises do
      run_command("boot_config", "set", "--publish-host-ip", "1.2.3.invalidIP", "--publish-host-ip", "::1")
    end

    assert_includes exception.message, "Invalid publish IP address: 1.2.3.invalidIP"
  end

  test "boot_config set docker options" do
    run_command("boot_config", "set", "--docker_options", "label=foo=bar", "add_host=thishost:thathost").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Uploading \"--publish 80:80 --publish 443:443 --log-opt max-size=10m --label=foo=bar --add_host=thishost:thathost\" to .kamal/proxy/options on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image_version on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set registry" do
    run_command("boot_config", "set", "--registry", "myreg").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/options on #{host}", output
        assert_match "Uploading \"myreg/basecamp/kamal-proxy\" to .kamal/proxy/image on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image_version on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set repository" do
    run_command("boot_config", "set", "--repository", "myrepo").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/options on #{host}", output
        assert_match "Uploading \"myrepo/kamal-proxy\" to .kamal/proxy/image on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image_version on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set image_version" do
    run_command("boot_config", "set", "--image_version", "0.9.9").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/options on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image on #{host}", output
        assert_match "Uploading \"0.9.9\" to .kamal/proxy/image_version on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set run_command" do
    run_command("boot_config", "set", "--metrics_port", "9000", "--debug", "true").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Running /usr/bin/env mkdir -p .kamal/proxy on #{host}", output
        assert_match "Uploading \"--publish 80:80 --publish 443:443 --log-opt max-size=10m --expose=9000\" to .kamal/proxy/options on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image on #{host}", output
        assert_match "Running /usr/bin/env rm .kamal/proxy/image_version on #{host}", output
        assert_match "Uploading \"kamal-proxy run --debug --metrics-port \\\"9000\\\"\" to .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config set all" do
    run_command("boot_config", "set", "--docker_options", "label=foo=bar", "--registry", "myreg", "--repository", "myrepo", "--image_version", "0.9.9", "--metrics_port", "9000", "--debug", "true").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "Uploading \"--publish 80:80 --publish 443:443 --log-opt max-size=10m --expose=9000 --label=foo=bar\" to .kamal/proxy/options on #{host}", output
        assert_match "Uploading \"myreg/myrepo/kamal-proxy\" to .kamal/proxy/image on #{host}", output
        assert_match "Uploading \"0.9.9\" to .kamal/proxy/image_version on #{host}", output
        assert_match "Uploading \"kamal-proxy run --debug --metrics-port \\\"9000\\\"\" to .kamal/proxy/run_command on #{host}", output
      end
    end
  end

  test "boot_config get" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:echo, "$(cat .kamal/proxy/options 2> /dev/null || echo \"--publish 80:80 --publish 443:443 --log-opt max-size=10m\") $(cat .kamal/proxy/image 2> /dev/null || echo \"basecamp/kamal-proxy\"):$(cat .kamal/proxy/image_version 2> /dev/null || echo \"#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}\") $(cat .kamal/proxy/run_command 2> /dev/null || echo \"\")")
      .returns("--publish 80:80 --publish 8443:443 --label=foo=bar basecamp/kamal-proxy:v1.0.0")
      .twice

    run_command("boot_config", "get").tap do |output|
      assert_match "Host 1.1.1.1: --publish 80:80 --publish 8443:443 --label=foo=bar basecamp/kamal-proxy:v1.0.0", output
      assert_match "Host 1.1.1.2: --publish 80:80 --publish 8443:443 --label=foo=bar basecamp/kamal-proxy:v1.0.0", output
    end
  end

  test "boot_config reset" do
    run_command("boot_config", "reset").tap do |output|
      %w[ 1.1.1.1 1.1.1.2 ].each do |host|
        assert_match "rm .kamal/proxy/options on #{host}", output
      end
    end
  end

  private
    def run_command(*command, fixture: :with_proxy)
      stdouted { Kamal::Cli::Proxy.start([ *command, "-c", "test/fixtures/deploy_#{fixture}.yml" ]) }
    end
end
