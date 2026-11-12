require_relative "cli_test_case"

class CliAppTest < CliTestCase
  test "boot" do
    stub_running
    run_command("boot").tap do |output|
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} /, output
      assert_match "docker container ls --all --filter 'name=^app-web-123$' --quiet | xargs docker stop", output
    end
  end

  test "boot through main names the subcommand to hooks and the output loggers" do
    stub_running
    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)

    hook_env = {}
    SSHKit::Backend::Abstract.any_instance.stubs(:execute).with do |*args|
      hook_env[args.first] = ENV.slice("KAMAL_COMMAND", "KAMAL_SUBCOMMAND") if args.first.to_s.start_with?(".kamal/hooks/")
      true
    end

    modifications = []
    subscriber = ActiveSupport::Notifications.subscribe("modify.kamal") do |*, payload|
      modifications << payload.slice(:command, :subcommand)
    end

    stdouted { Kamal::Cli::Main.start([ "app", "boot", "-c", "test/fixtures/deploy_with_accessories.yml", "--hosts", "1.1.1.1" ]) }

    assert_equal({ "KAMAL_COMMAND" => "app", "KAMAL_SUBCOMMAND" => "boot" }, hook_env[".kamal/hooks/pre-app-boot"])
    assert_equal [ { command: "app", subcommand: "boot" } ], modifications
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "boot will rename if same version is already running" do
    Object.any_instance.stubs(:sleep)
    run_command("details") # Preheat Kamal const

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-web-latest$'", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-web-latest$'", "--quiet")
      .returns("12345678") # running version

    run_command("boot").tap do |output|
      assert_match /Renaming container .* to .* as already deployed on 1.1.1.1/, output # Rename
      assert_match /docker rename app-web-latest app-web-latest_replaced_[0-9a-f]{16}/, output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} /, output
      assert_match "docker container ls --all --filter 'name=^app-web-123$' --quiet | xargs docker stop", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "boot uses group strategy when specified" do
    Kamal::Cli::App.any_instance.stubs(:on).with("1.1.1.1").twice
    Kamal::Cli::App.any_instance.stubs(:on).with([ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ]).times(3)

    # Strategy is used when booting the containers
    Kamal::Cli::App.any_instance.expects(:on).with([ "1.1.1.1", "1.1.1.2", "1.1.1.3" ]).with_block_given
    Kamal::Cli::App.any_instance.expects(:on).with([ "1.1.1.4" ]).with_block_given
    Object.any_instance.expects(:sleep).with(2).twice

    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)

    run_command("boot", config: :with_boot_strategy, host: nil).tap do |output|
      assert_hook_ran "pre-app-boot", output, count: 2
      assert_hook_ran "post-app-boot", output, count: 2
    end
  end

  test "boot without parallel roles" do
    # Without parallel_roles: on() called with all hosts, roles sequential per host
    Kamal::Cli::App.any_instance.expects(:on).with("1.1.1.1").with_block_given.twice
    Kamal::Cli::App.any_instance.expects(:on).with([ "1.1.1.1", "1.1.1.2", "1.1.1.3" ]).with_block_given.times(4)

    run_command("boot", config: :without_parallel_roles, host: nil)
  end

  test "boot with parallel roles" do
    # With parallel_roles: each role gets its own on() call
    Kamal::Cli::App.any_instance.expects(:on).with("1.1.1.1").with_block_given.twice
    Kamal::Cli::App.any_instance.expects(:on).with([ "1.1.1.1", "1.1.1.2", "1.1.1.3" ]).with_block_given.times(3)
    Kamal::Cli::App.any_instance.expects(:on).with([ "1.1.1.1", "1.1.1.2" ]).with_block_given
    Kamal::Cli::App.any_instance.expects(:on).with([ "1.1.1.1", "1.1.1.3" ]).with_block_given

    run_command("boot", config: :with_parallel_roles, host: nil)
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
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-web-latest$'", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("123").twice # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-web-latest$'", "--quiet")
      .returns("12345678") # running version

    run_command("boot", config: :with_assets).tap do |output|
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match "/usr/bin/env mkdir -p .kamal/apps/app/assets/volumes/web-latest ; cp -rnT .kamal/apps/app/assets/extracted/web-latest .kamal/apps/app/assets/volumes/web-latest ; cp -rnT .kamal/apps/app/assets/extracted/web-latest .kamal/apps/app/assets/volumes/web-123 || true ; cp -rnT .kamal/apps/app/assets/extracted/web-123 .kamal/apps/app/assets/volumes/web-latest || true", output
      assert_match "/usr/bin/env mkdir -p .kamal/apps/app/assets/extracted/web-latest && docker container rm app-web-assets 2> /dev/null || true && docker container create --name app-web-assets dhh/app:latest && docker container cp -L app-web-assets:/public/assets/. .kamal/apps/app/assets/extracted/web-latest && docker container rm app-web-assets", output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} /, output
      assert_match "docker container ls --all --filter 'name=^app-web-123$' --quiet | xargs docker stop", output
      assert_match "/usr/bin/env find .kamal/apps/app/assets/extracted -maxdepth 1 -name 'web-*' ! -name web-latest -exec rm -rf \"{}\" + ; find .kamal/apps/app/assets/volumes -maxdepth 1 -name 'web-*' ! -name web-latest -exec rm -rf \"{}\" +", output
    end
  end

  test "boot with host tags" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-web-latest$'", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-web-latest$'", "--quiet")
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("123") # old version

    run_command("boot", config: :with_env_tags).tap do |output|
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match %r{docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} --env KAMAL_CONTAINER_NAME="app-web-latest" --env KAMAL_VERSION="latest" --env KAMAL_HOST="1.1.1.1" --env TEST="root" --env EXPERIMENT="disabled" --env SITE="site1"}, output
      assert_match "docker container ls --all --filter 'name=^app-web-123$' --quiet | xargs docker stop", output
    end
  end

  test "boot with web barrier opened" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-workers-latest$'", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
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
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-web-latest$'", "--quiet", "|", :xargs, :docker, :stop, raise_on_non_zero_exit: false)
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
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-workers-latest$'", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
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
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-workers-latest$'", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running", "stopped").at_least_once # workers health check

    run_command("boot", config: :with_roles, host: "1.1.1.3", allow_execute_error: true).tap do |output|
      assert_match "ERROR Failed to boot workers on 1.1.1.3", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "boot with only workers" do
    Object.any_instance.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-workers-latest$'", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # workers health check

    run_command("boot", config: :with_only_workers, host: nil).tap do |output|
      assert_match /First workers container is healthy on 1.1.1.\d, booting any other roles/, output
      assert_no_match "kamal-proxy", output
    end
  end

  test "boot with error pages" do
    with_error_pages(directory: "public") do
      stub_running
      run_command("boot", config: :with_error_pages).tap do |output|
        assert_match /Uploading .*kamal-error-pages.*\/latest to \.kamal\/proxy\/apps-config\/app\/error_pages/, output
        assert_match "docker tag dhh/app:latest dhh/app:latest", output
        assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} /, output
        assert_match "docker container ls --all --filter 'name=^app-web-123$' --quiet | xargs docker stop", output
        assert_match "Running /usr/bin/env find .kamal/proxy/apps-config/app/error_pages -mindepth 1 -maxdepth 1 ! -name latest -exec rm -rf {} + on 1.1.1.1", output
      end
    end
  end

  test "boot with custom ssl certificate" do
    Kamal::Configuration::Proxy.any_instance.stubs(:custom_ssl_certificate?).returns(true)
    Kamal::Configuration::Proxy.any_instance.stubs(:certificate_pem_content).returns("CERTIFICATE CONTENT")
    Kamal::Configuration::Proxy.any_instance.stubs(:private_key_pem_content).returns("PRIVATE KEY CONTENT")

    stub_running
    run_command("boot", config: :with_proxy).tap do |output|
      assert_match "Writing SSL certificates for web on 1.1.1.1", output
      assert_match "mkdir -p .kamal/proxy/apps-config/app/tls", output
      assert_match "Uploading \"CERTIFICATE CONTENT\" to .kamal/proxy/apps-config/app/tls/web/cert.pem", output
      assert_match "--tls-certificate-path=\"/home/kamal-proxy/.apps-config/app/tls/web/cert.pem\"", output
      assert_match "--tls-private-key-path=\"/home/kamal-proxy/.apps-config/app/tls/web/key.pem\"", output
    end
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
      assert_match /#{Regexp.escape("docker container ls --all --filter 'name=^app-web-87654321$' --quiet | xargs docker stop")}/, output
    end
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match "docker ps --filter label=service=app --filter label=destination= --filter label=role=web", output
    end
  end

  test "remove" do
    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)

    run_command("remove").tap do |output|
      assert_hook_ran "pre-app-remove", output
      assert_match "sh -c 'docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | xargs docker stop", output
      assert_match "docker container prune --force --filter label=service=app", output
      assert_match "docker image prune --all --force --filter label=service=app", output
      assert_match "rm -r .kamal/apps/app on 1.1.1.1", output
      assert_match "rm -r .kamal/proxy/apps-config/app on 1.1.1.1", output
      assert_hook_ran "post-app-remove", output
    end
  end

  test "remove with role filter does not remove images or app directories" do
    run_command("remove", "-r", "workers", config: :with_two_roles_one_host).tap do |output|
      assert_match "docker stop", output
      assert_match "docker container prune --force --filter label=service=app", output
      # Images and directories should NOT be removed when other roles remain on the host
      assert_no_match(/docker image prune --all --force --filter label=service=app/, output)
      assert_no_match(/rm -r .kamal\/apps\/app/, output)
      assert_no_match(/rm -r .kamal\/proxy\/apps-config\/app/, output)
    end
  end

  test "remove with all roles on host removes images and app directories" do
    run_command("remove", "-r", "workers,web", config: :with_two_roles_one_host).tap do |output|
      assert_match "docker stop", output
      assert_match "docker container prune --force --filter label=service=app", output
      # Images and directories SHOULD be removed when all roles on host are removed
      assert_match "docker image prune --all --force --filter label=service=app", output
      assert_match "rm -r .kamal/apps/app on 1.1.1.1", output
      assert_match "rm -r .kamal/proxy/apps-config/app on 1.1.1.1", output
    end
  end

  test "remove_container" do
    run_command("remove_container", "1234567").tap do |output|
      assert_match "docker container ls --all --filter 'name=^app-web-1234567$' --quiet | xargs docker container rm", output
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

  test "remove_app_directories" do
    run_command("remove_app_directories").tap do |output|
      assert_match "rm -r .kamal/apps/app on 1.1.1.1", output
      assert_match "rm -r .kamal/proxy/apps-config/app on 1.1.1.1", output
    end
  end

  test "exec" do
    run_command("exec", "ruby -v").tap do |output|
      assert_match "docker login -u [REDACTED] -p [REDACTED]", output
      assert_match %r{docker run --rm --name app-web-exec-latest-[0-9a-f]{6} --network kamal --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size="10m" dhh/app:latest ruby -v}, output
    end
  end

  test "exec without command fails" do
    error = assert_raises(ArgumentError, "Exec requires a command to be specified") do
      run_command("exec")
    end
    assert_equal "No command provided. You must specify a command to execute.", error.message
  end

  test "exec separate arguments" do
    run_command("exec", "ruby", " -v").tap do |output|
      assert_match %r{docker run --rm --name app-web-exec-latest-[0-9a-f]{6} --network kamal --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size="10m" dhh/app:latest ruby -v}, output
    end
  end

  test "exec detach" do
    run_command("exec", "--detach", "ruby -v").tap do |output|
      assert_match %r{docker run --detach --name app-web-exec-latest-[0-9a-f]{6} --network kamal --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size="10m" dhh/app:latest ruby -v}, output
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
    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    SSHKit::Backend::Abstract.any_instance.expects(:exec)
      .with(regexp_matches(%r{ssh -t root@1\.1\.1\.1 -p 22 'docker run -it --rm --name app-web-exec-latest-[0-9a-f]{6} --network kamal --env-file .kamal/apps/app/env/roles/web.env --log-opt max-size="10m" dhh/app:latest ruby -v'}))

    stub_stdin_tty do
      run_command("exec", "-i", "ruby -v").tap do |output|
        assert_hook_ran "pre-connect", output
        assert_match "docker login -u [REDACTED] -p [REDACTED]", output
        assert_match "Get most recent version available as an image...", output
        assert_match "Launching interactive command with version latest via SSH from new container on 1.1.1.1...", output
      end
    end
  end

  test "exec interactive with reuse" do
    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    SSHKit::Backend::Abstract.any_instance.expects(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker exec -it app-web-999 ruby -v'")

    stub_stdin_tty do
      run_command("exec", "-i", "--reuse", "ruby -v").tap do |output|
        assert_hook_ran "pre-connect", output
        assert_match "Get current version of running container...", output
        assert_match "Running /usr/bin/env sh -c 'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | while read line; do echo ${line#app-web-}; done on 1.1.1.1", output
        assert_match "Launching interactive command with version 999 via SSH from existing container on 1.1.1.1...", output
      end
    end
  end

  test "exec interactive with pipe on STDIN" do
    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    SSHKit::Backend::Abstract.any_instance.expects(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'docker exec -i app-web-999 ruby -v'")

    stub_stdin_file do
      run_command("exec", "-i", "--reuse", "ruby -v").tap do |output|
        assert_hook_ran "pre-connect", output
        assert_match "Launching interactive command with version 999 via SSH from existing container on 1.1.1.1...", output
      end
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
      .with("ssh -t root@1.1.1.1 -p 22 'sh -c '\\''echo ID123'\\'' | xargs docker logs --timestamps --tail 10 --follow 2>&1'")

    assert_match "sh -c '\\''echo ID123'\\'' | xargs docker logs --timestamps --tail 10 --follow 2>&1", run_command("logs", "--follow", "--container-id", "ID123")
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

  test "logs with follow and since" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 -p 22 'sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --since 5m --follow 2>&1'")

    assert_match "sh -c '\\''docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''\\'\\'''\\''{{.ID}}'\\''\\'\\'''\\'') ; docker ps --latest --quiet --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'\\'' | head -1 | xargs docker logs --timestamps --since 5m --follow 2>&1", run_command("logs", "--follow", "--since", "5m")
  end

  test "version" do
    run_command("version").tap do |output|
      assert_match "sh -c 'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | while read line; do echo ${line#app-web-}; done", output
    end
  end


  test "version through main" do
    with_argv([ "app", "version", "-c", "test/fixtures/deploy_with_accessories.yml", "--hosts", "1.1.1.1" ]) do
      stdouted { Kamal::Cli::Main.start }.tap do |output|
        assert_match "sh -c 'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting' | head -1 | while read line; do echo ${line#app-web-}; done", output
      end
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
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --network kamal --hostname 1.1.1.1-[0-9a-f]{12} --env KAMAL_CONTAINER_NAME="app-web-latest" --env KAMAL_VERSION="latest" --env KAMAL_HOST="1.1.1.1" --env-file .kamal\/apps\/app\/env\/roles\/web.env --log-opt max-size="10m" --label service="app" --label role="web" --label destination dhh\/app:latest/, output
      assert_match /docker exec kamal-proxy kamal-proxy deploy app-web --target="123:80"/, output
      assert_match "docker container ls --all --filter 'name=^app-web-123$' --quiet | xargs docker stop", output
    end
  end

  test "boot proxy with role specific config" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

    run_command("boot", config: :with_proxy_roles, host: nil).tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web --target=\"123:80\" --deploy-timeout=\"6s\" --drain-timeout=\"30s\" --target-timeout=\"10s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"", output
      assert_match "docker exec kamal-proxy kamal-proxy deploy app-web2 --target=\"123:80\" --deploy-timeout=\"6s\" --drain-timeout=\"30s\" --target-timeout=\"15s\" --buffer-requests --buffer-responses --log-request-header=\"Cache-Control\" --log-request-header=\"Last-Modified\" --log-request-header=\"User-Agent\"", output
    end
  end

  test "live" do
    run_command("live").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy resume app-web on 1.1.1.1", output
    end
  end

  test "maintenance" do
    run_command("maintenance").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy stop app-web --drain-timeout=\"30s\" on 1.1.1.1", output
    end
  end

  test "maintenance with options" do
    run_command("maintenance", "--message", "Hello", "--drain_timeout", "10").tap do |output|
      assert_match "docker exec kamal-proxy kamal-proxy stop app-web --drain-timeout=\"10s\" --message=\"Hello\" on 1.1.1.1", output
    end
  end

  test "renew_certificates" do
    with_ssl_proxy_config do |config_file|
      run_command("renew_certificates", "-y", config_file: config_file).tap do |output|
        assert_match "docker exec kamal-proxy kamal-proxy cert renew app-web on 1.1.1.1", output
        assert_match "Renewed certificates for all hosts (web) on 1.1.1.1", output
        assert_no_match "app-workers", output
      end
    end
  end

  test "renew_certificates with domains" do
    with_ssl_proxy_config(hosts: [ "example.com", "www.example.com" ]) do |config_file|
      run_command("renew_certificates", "-y", "--domains", "www.example.com", config_file: config_file).tap do |output|
        assert_match "docker exec kamal-proxy kamal-proxy cert renew app-web --host=\"www.example.com\" on 1.1.1.1", output
        assert_match "Renewed certificates for www.example.com (web) on 1.1.1.1", output
        assert_no_match "--host=\"example.com\"", output
      end
    end
  end

  test "renew_certificates normalizes domains" do
    with_ssl_proxy_config(hosts: [ "Example.com", "www.example.com" ]) do |config_file|
      run_command("renew_certificates", "-y", "--domains", "EXAMPLE.com.", config_file: config_file).tap do |output|
        assert_match "docker exec kamal-proxy kamal-proxy cert renew app-web --host=\"example.com\" on 1.1.1.1", output
        assert_no_match "www.example.com", output
      end
    end
  end

  test "renew_certificates with empty domains" do
    with_ssl_proxy_config do |config_file|
      [ "", "," ].each do |domains|
        error = assert_raises(ArgumentError) do
          run_command("renew_certificates", "-y", "--domains", domains, config_file: config_file)
        end
        assert_equal "No domains given", error.message
      end
    end
  end

  test "renew_certificates with unknown domains" do
    with_ssl_proxy_config do |config_file|
      error = assert_raises(ArgumentError) do
        run_command("renew_certificates", "-y", "--domains", "example.com,other.example.com", config_file: config_file)
      end
      assert_equal "No automatic SSL certificate for domains: other.example.com (check the role's proxy hosts, SSL settings and the --roles/--hosts filters)", error.message
    end
  end

  test "renew_certificates with a domain on a role without ssl" do
    with_ssl_proxy_config(servers: {
      "web" => { "hosts" => [ "1.1.1.1" ], "proxy" => { "ssl" => true, "hosts" => [ "example.com" ] } },
      "api" => { "hosts" => [ "1.1.1.2" ], "proxy" => { "hosts" => [ "api.example.com" ] } }
    }) do |config_file|
      error = assert_raises(ArgumentError) do
        run_command("renew_certificates", "-y", "--domains", "api.example.com", config_file: config_file, host: nil)
      end
      assert_equal "No automatic SSL certificate for domains: api.example.com (check the role's proxy hosts, SSL settings and the --roles/--hosts filters)", error.message
    end
  end

  test "renew_certificates with domains on one of several ssl roles" do
    with_ssl_proxy_config(servers: {
      "web" => { "hosts" => [ "1.1.1.1" ], "proxy" => { "ssl" => true, "hosts" => [ "example.com" ] } },
      "api" => { "hosts" => [ "1.1.1.2" ], "proxy" => { "ssl" => true, "hosts" => [ "api.example.com" ] } }
    }) do |config_file|
      run_command("renew_certificates", "-y", "--domains", "api.example.com", config_file: config_file, host: nil).tap do |output|
        assert_match "docker exec kamal-proxy kamal-proxy cert renew app-api --host=\"api.example.com\" on 1.1.1.2", output
        assert_no_match "cert renew app-web", output
      end
    end
  end

  test "renew_certificates skips roles with custom ssl certificates" do
    with_test_secrets("secrets" => "CERT_PEM=certificate\nKEY_PEM=private_key") do
      with_ssl_proxy_config(servers: {
        "web" => { "hosts" => [ "1.1.1.1" ], "proxy" => { "ssl" => true, "hosts" => [ "example.com" ] } },
        "api" => { "hosts" => [ "1.1.1.2" ], "proxy" => { "ssl" => { "certificate_pem" => "CERT_PEM", "private_key_pem" => "KEY_PEM" }, "hosts" => [ "api.example.com" ] } }
      }) do |config_file|
        run_command("renew_certificates", "-y", config_file: config_file, host: nil).tap do |output|
          assert_match "docker exec kamal-proxy kamal-proxy cert renew app-web on 1.1.1.1", output
          assert_no_match "cert renew app-api", output
        end
      end
    end
  end

  test "renew_certificates with an older kamal-proxy" do
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.stubs(:execute).returns(true)
    SSHKit::Backend::Abstract.any_instance.expects(:execute)
      .with(:docker, :exec, "kamal-proxy", "kamal-proxy", :cert, :renew, "app-web")
      .raises(SSHKit::Command::Failed.new("docker exit status: 1\ndocker stderr: Error: unknown command \"cert\" for \"kamal-proxy\""))

    with_ssl_proxy_config do |config_file|
      error = assert_raises(SSHKit::Runner::ExecuteError) do
        run_command("renew_certificates", "-y", config_file: config_file)
      end
      assert_includes error.message, "kamal-proxy on 1.1.1.1 doesn't support certificate renewal, upgrade it (e.g. with `kamal proxy reboot`) once a release supports it"
    end
  ensure
    Thread.report_on_exception = true
  end

  test "renew_certificates asks for confirmation" do
    Kamal::Cli::App.any_instance.expects(:ask)
      .with("This will request new certificates from Let's Encrypt, and renewals count towards its rate limits for the same domains. Are you sure?", limited_to: %w[ y N ], default: "N")
      .returns("N")

    with_ssl_proxy_config do |config_file|
      run_command("renew_certificates", config_file: config_file).tap do |output|
        assert_match "Aborted", output
        assert_no_match "cert renew", output
      end
    end
  end

  test "renew_certificates without automatic ssl" do
    run_command("renew_certificates", "-y", config: :with_proxy).tap do |output|
      assert_match "No roles use automatic SSL certificates, nothing to renew", output
      assert_no_match "cert renew", output
    end
  end

  private
    def run_command(*command, config: :with_accessories, config_file: nil, host: "1.1.1.1", allow_execute_error: false)
      config_file ||= "test/fixtures/deploy_#{config}.yml"
      stdouted do
        Kamal::Cli::App.start([ *command, "-c", config_file, *([ "--hosts", host ] if host) ])
      rescue SSHKit::Runner::ExecuteError => e
        raise e unless allow_execute_error
      end
    end

    def with_ssl_proxy_config(hosts: [ "example.com" ], servers: nil)
      Dir.mktmpdir do |dir|
        config_file = File.join(dir, "deploy.yml")
        File.write config_file, {
          "service" => "app",
          "image" => "dhh/app",
          "registry" => { "username" => "user", "password" => "pw" },
          "builder" => { "arch" => "amd64" },
          "servers" => servers || {
            "web" => { "hosts" => [ "1.1.1.1" ], "proxy" => { "ssl" => true, "hosts" => hosts } },
            "workers" => { "hosts" => [ "1.1.1.2" ], "cmd" => "bin/jobs" }
          }
        }.to_yaml

        yield config_file
      end
    end

    def stub_running
      Object.any_instance.stubs(:sleep)

      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version
    end
end
