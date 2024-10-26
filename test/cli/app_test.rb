require_relative "cli_test_case"

class CliAppTest < CliTestCase
  test "boot" do
    stub_running
    run_command("boot").tap do |output|
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} /, output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
    end
  end

  test "boot will rename if same version is already running" do
    Object.any_instance.stubs(:sleep)
    run_command("details") # Preheat Kamal const

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet")
      .returns("12345678") # running version

    run_command("boot").tap do |output|
      assert_match /Renaming container .* to .* as already deployed on 1.1.1.1/, output # Rename
      assert_match /docker rename app-web-latest app-web-latest_replaced_[0-9a-f]{16}/, output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} /, output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "boot uses group strategy when specified" do
    Kamal::Cli::App.any_instance.stubs(:on).with("1.1.1.1").times(2) # ensure locks dir, acquire & release lock
    Kamal::Cli::App.any_instance.stubs(:on).with([ "1.1.1.1" ]) # tag container

    # Strategy is used when booting the containers
    Kamal::Cli::App.any_instance.expects(:on).with([ "1.1.1.1" ], in: :groups, limit: 3, wait: 2).with_block_given

    run_command("boot", config: :with_boot_strategy)
  end

  test "boot errors don't leave lock in place" do
    Kamal::Cli::App.any_instance.expects(:using_version).raises(RuntimeError)

    assert_not KAMAL.holding_lock?
    assert_raises(RuntimeError) do
      stderred { run_command("boot") }
    end
    assert_not KAMAL.holding_lock?
  end

  test "boot with assets" do
    Object.any_instance.stubs(:sleep)
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("123").twice # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet")
      .returns("12345678") # running version

    run_command("boot", config: :with_assets).tap do |output|
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match "/usr/bin/env mkdir -p .kamal/apps/app/assets/volumes/web-latest ; cp -rnT .kamal/apps/app/assets/extracted/web-latest .kamal/apps/app/assets/volumes/web-latest ; cp -rnT .kamal/apps/app/assets/extracted/web-latest .kamal/apps/app/assets/volumes/web-123 || true ; cp -rnT .kamal/apps/app/assets/extracted/web-123 .kamal/apps/app/assets/volumes/web-latest || true", output
      assert_match "/usr/bin/env mkdir -p .kamal/apps/app/assets/extracted/web-latest && docker stop -t 1 app-web-assets 2> /dev/null || true && docker run --name app-web-assets --detach --rm --entrypoint sleep dhh/app:latest 1000000 && docker cp -L app-web-assets:/public/assets/. .kamal/apps/app/assets/extracted/web-latest && docker stop -t 1 app-web-assets", output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} /, output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
      assert_match "/usr/bin/env find .kamal/apps/app/assets/extracted -maxdepth 1 -name 'web-*' ! -name web-latest -exec rm -rf \"{}\" + ; find .kamal/apps/app/assets/volumes -maxdepth 1 -name 'web-*' ! -name web-latest -exec rm -rf \"{}\" +", output
    end
  end

  test "boot with host tags" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet")
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("123") # old version

    run_command("boot", config: :with_env_tags).tap do |output|
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match %r{docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} -e KAMAL_CONTAINER_NAME="app-web-latest" -e KAMAL_VERSION="latest" --env TEST="root" --env EXPERIMENT="disabled" --env SITE="site1"}, output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
    end
  end

  test "boot with web barrier opened" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # workers health check

    run_command("boot", config: :with_roles, host: nil).tap do |output|
      assert_match "Waiting for the first healthy web container before booting workers on 1.1.1.3...", output
      assert_match "Waiting for the first healthy web container before booting workers on 1.1.1.4...", output
      assert_match "First web container is healthy, booting workers on 1.1.1.3", output
      assert_match "First web container is healthy, booting workers on 1.1.1.4", output
    end
  end

  test "boot with web barrier closed" do
    Thread.report_on_exception = false

    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.stubs(:execute).returns("")
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", "|", :xargs, :docker, :stop, raise_on_non_zero_exit: false)
    SSHKit::Backend::Abstract.any_instance.expects(:execute)
      .with(:docker, :exec, "kamal-proxy", "kamal-proxy", :deploy, "app-web", "--target=\"123:80\"", "--deploy-timeout=\"1s\"", "--drain-timeout=\"30s\"", "--buffer-requests", "--buffer-responses", "--log-request-header=\"Cache-Control\"", "--log-request-header=\"Last-Modified\"", "--log-request-header=\"User-Agent\"").raises(SSHKit::Command::Failed.new("Failed to deploy"))

    stderred do
      run_command("boot", config: :with_roles, host: nil, allow_execute_error: true).tap do |output|
        assert_match "Waiting for the first healthy web container before booting workers on 1.1.1.3...", output
        assert_match "Waiting for the first healthy web container before booting workers on 1.1.1.4...", output
        assert_match "First web container is unhealthy, not booting workers on 1.1.1.3", output
        assert_match "First web container is unhealthy, not booting workers on 1.1.1.4", output
      end
    end
  ensure
    Thread.report_on_exception = true
  end

  test "boot with worker errors" do
    Thread.report_on_exception = false

    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("unhealthy").at_least_once # workers health check

    run_command("boot", config: :with_roles, host: nil, allow_execute_error: true).tap do |output|
      assert_match "Waiting for the first healthy web container before booting workers on 1.1.1.3...", output
      assert_match "Waiting for the first healthy web container before booting workers on 1.1.1.4...", output
      assert_match "First web container is healthy, booting workers on 1.1.1.3", output
      assert_match "First web container is healthy, booting workers on 1.1.1.4", output
      assert_match "ERROR Failed to boot workers on 1.1.1.3", output
      assert_match "ERROR Failed to boot workers on 1.1.1.4", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "boot with worker ready then not" do
    Thread.report_on_exception = false

    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running", "stopped").at_least_once # workers health check

    run_command("boot", config: :with_roles, host: "1.1.1.3", allow_execute_error: true).tap do |output|
      assert_match "ERROR Failed to boot workers on 1.1.1.3", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "start" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("999") # old version

    run_command("start").tap do |output|
      assert_match "docker start app-web-999", output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target=\"999:80\" --deploy-timeout=\"30s\" --drain-timeout=\"30s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\"", output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker stop", output
    end
  end

  test "stale_containers" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :ps, "--filter", "label=service=app", "--filter", "label=destination=", "--filter", "label=role=web", "--format", "\"{{.Names}}\"", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("12345678\n87654321\n")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("12345678\n")

    run_command("stale_containers").tap do |output|
      assert_match /Detected stale container for role web with version 87654321/, output
    end
  end

  test "stop stale_containers" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :ps, "--filter", "label=service=app", "--filter", "label=destination=", "--filter", "label=role=web", "--format", "\"{{.Names}}\"", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("12345678\n87654321\n")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("12345678\n")

    run_command("stale_containers", "--stop").tap do |output|
      assert_match /Stopping stale container for role web with version 87654321/, output
      assert_match /#{Regexp.escape("docker container ls --all --filter name=^app-web-87654321$ --quiet | xargs docker stop")}/, output
    end
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match "docker ps --filter label=service=app --filter label=destination= --filter label=role=web", output
    end
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match /#{Regexp.escape("sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker stop")}/, output
      assert_match /#{Regexp.escape("docker container prune --force --filter label=service=app")}/, output
      assert_match /#{Regexp.escape("docker image prune --all --force --filter label=service=app")}/, output
    end
  end

  test "remove_container" do
    run_command("remove_container", "1234567").tap do |output|
      assert_match "docker container ls --all --filter name=^app-web-1234567$ --quiet | xargs docker container rm", output
    end
  end

  test "remove_containers" do
    run_command("remove_containers").tap do |output|
      assert_match "docker container prune --force --filter label=service=app", output
    end
  end

  test "remove_images" do
    run_command("remove_images").tap do |output|
      assert_match "docker image prune --all --force --filter label=service=app", output
    end
  end

  test "exec" do
    run_command("exec", "ruby -v").tap do |output|
      assert_match "docker run --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size=\"10m\" dhh/app:latest ruby -v", output
    end
  end

  test "exec separate arguments" do
    run_command("exec", "ruby", " -v").tap do |output|
      assert_match "docker run --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size=\"10m\" dhh/app:latest ruby -v", output
    end
  end

  test "exec detach" do
    run_command("exec", "--detach", "ruby -v").tap do |output|
      assert_match "docker run --detach --network kamal --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size=\"10m\" dhh/app:latest ruby -v", output
    end
  end

  test "exec detach with reuse" do
    assert_raises(ArgumentError, "Detach is not compatible with reuse") do
      run_command("exec", "--detach", "--reuse", "ruby -v")
    end
  end

  test "exec detach with interactive" do
    assert_raises(ArgumentError, "Detach is not compatible with interactive") do
      run_command("exec", "--interactive", "--detach", "ruby -v")
    end
  end

  test "exec detach with interactive and reuse" do
    assert_raises(ArgumentError, "Detach is not compatible with interactive or reuse") do
      run_command("exec", "--interactive", "--detach", "--reuse", "ruby -v")
    end
  end

  test "exec with reuse" do
    run_command("exec", "--reuse", "ruby -v").tap do |output|
      assert_match "sh -c 'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | while read line; do echo ${line#app-web-}; done", output # Get current version
      assert_match "docker exec app-web-999 ruby -v", output
    end
  end

  test "exec interactive" do
    SSHKit::Backend::Abstract.any_instance.expects(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker run -it --rm --network kamal --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size=\"10m\" dhh/app:latest ruby -v'")
    run_command("exec", "-i", "ruby -v").tap do |output|
      assert_match "Get most recent version available as an image...", output
      assert_match "Launching interactive command with version latest via SSH from new container on 1.1.1.1...", output
    end
  end

  test "exec interactive with reuse" do
    SSHKit::Backend::Abstract.any_instance.expects(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker exec -it app-web-999 ruby -v'")
    run_command("exec", "-i", "--reuse", "ruby -v").tap do |output|
      assert_match "Get current version of running container...", output
      assert_match "Running /usr/bin/env sh -c 'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | while read line; do echo ${line#app-web-}; done on 1.1.1.1", output
      assert_match "Launching interactive command with version 999 via SSH from existing container on 1.1.1.1...", output
    end
  end

  test "containers" do
    run_command("containers").tap do |output|
      assert_match "docker container ls --all --filter label=service=app", output
    end
  end

  test "images" do
    run_command("images").tap do |output|
      assert_match "docker image ls dhh/app", output
    end
  end

  test "logs" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 'sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1| xargs docker logs --timestamps --tail 10 2>&1'")

    assert_match "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps --tail 100 2>&1", run_command("logs")

    assert_match "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps 2>&1 | grep 'hey'", run_command("logs", "--grep", "hey")

    assert_match "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker logs --timestamps 2>&1 | grep 'hey' -C 2", run_command("logs", "--grep", "hey", "--grep-options", "-C 2")
  end

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --tail 10 --follow 2>&1'")

    assert_match "sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --tail 10 --follow 2>&1", run_command("logs", "--follow")
  end

  test "logs with follow and container_id" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'echo ID123 | xargs docker logs --timestamps --tail 10 --follow 2>&1'")

    assert_match "echo ID123 | xargs docker logs --timestamps --tail 10 --follow 2>&1", run_command("logs", "--follow", "--container-id", "ID123")
  end

  test "logs with follow and grep" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --follow 2>&1 | grep \"hey\"'")

    assert_match "sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --follow 2>&1 | grep \"hey\"", run_command("logs", "--follow", "--grep", "hey")
  end

  test "logs with follow, grep and grep options" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --follow 2>&1 | grep \"hey\" -C 2'")

    assert_match "sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --follow 2>&1 | grep \"hey\" -C 2", run_command("logs", "--follow", "--grep", "hey", "--grep-options", "-C 2")
  end

  test "version" do
    run_command("version").tap do |output|
      assert_match "sh -c 'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | while read line; do echo ${line#app-web-}; done", output
    end
  end


  test "version through main" do
    stdouted { Kamal::Cli::Main.start([ "app", "version", "-c", "test/fixtures/deploy_with_accessories.yml", "--hosts", "1.1.1.1" ]) }.tap do |output|
      assert_match "sh -c 'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | while read line; do echo ${line#app-web-}; done", output
    end
  end

  test "long hostname" do
    stub_running

    hostname = "this-hostname-is-really-unacceptably-long-to-be-honest.example.com"

    stdouted { Kamal::Cli::App.start([ "boot", "-c", "test/fixtures/deploy_with_uncommon_hostnames.yml", "--hosts", hostname ]) }.tap do |output|
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname this-hostname-is-really-unacceptably-long-to-be-hon-[0-9a-f]{12} /, output
    end
  end

  test "hostname is trimmed if will end with a period" do
    stub_running

    hostname = "this-hostname-with-random-part-is-too-long.example.com"

    stdouted { Kamal::Cli::App.start([ "boot", "-c", "test/fixtures/deploy_with_uncommon_hostnames.yml", "--hosts", hostname ]) }.tap do |output|
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname this-hostname-with-random-part-is-too-long.example-[0-9a-f]{12} /, output
    end
  end

  test "boot proxy" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    run_command("boot", config: :with_proxy).tap do |output|
      assert_match /Renaming container .* to .* as already deployed on 1.1.1.1/, output # Rename
      assert_match /docker rename app-web-latest app-web-latest_replaced_[0-9a-f]{16}/, output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} -e KAMAL_CONTAINER_NAME="app-web-latest" -e KAMAL_VERSION="latest" --env-file .kamal\/apps\/app\/env\/roles\/web.env --log-opt max-size="10m" --label service="app" --label role="web" --label destination dhh\/app:latest/, output
      assert_match /docker exec kamal-proxy kamal-proxy deploy app-web --target="123:80"/, output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
    end
  end

  test "boot proxy with role specific config" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    run_command("boot", config: :with_proxy_roles, host: nil).tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target=\"123:80\" --deploy-timeout=\"6s\" --drain-timeout=\"30s\" --target-timeout=\"10s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"", output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web2 --target=\"123:80\" --deploy-timeout=\"6s\" --drain-timeout=\"30s\" --target-timeout=\"15s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"", output
    end
  end

  private
    def run_command(*command, config: :with_accessories, host: "1.1.1.1", allow_execute_error: false)
      stdouted do
        Kamal::Cli::App.start([ *command, "-c", "test/fixtures/deploy_#{config}.yml", *([ "--hosts", host ] if host) ])
      rescue SSHKit::Runner::ExecuteError => e
        raise e unless allow_execute_error
      end
    end

    def stub_running
      Object.any_instance.stubs(:sleep)

      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version
    end
end
