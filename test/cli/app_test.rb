require_relative "cli_test_case"

class CliAppTest < CliTestCase
  test "boot with pre-app-drain hook" do
    stub_running
    stub_drain_hook

    Kamal::Commands::Hook.any_instance.expects(:env).with(
      hosts: "1.1.1.1", role: "web", lock: "true", command: "app", subcommand: "boot",
      draining_version: "123", draining_container_id: "123"
    ).returns({})

    run_command("boot").tap do |output|
      assert_match(/pre-app-drain.*wait-drain drain-123.*name=\^app-web-123\$.*docker stop/m, output)
    end
  end

  test "boot without old container skips pre-app-drain" do
    stub_running
    stub_drain_hook
    Kamal::Commands::App.any_instance.stubs(:current_running_version).returns([ :old_version ])
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with(:old_version, raise_on_non_zero_exit: false).returns("")

    run_command("boot").tap do |output|
      assert_no_match(/pre-app-drain|async-drain|wait-drain/, output)
    end
  end

  test "pre-app-drain identifies the renamed container when redeploying the same version" do
    stub_running
    stub_drain_hook
    Kamal::Commands::App.any_instance.stubs(:current_running_version).returns([ :old_version ])
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with(:old_version, raise_on_non_zero_exit: false)
      .returns("latest_replaced_existing")
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "'name=^app-web-latest_replaced_existing$'", "--quiet")
      .returns("retiring-container")
    Kamal::Commands::Hook.any_instance.expects(:env).with do |**details|
      details[:draining_version] == "latest_replaced_existing" && details[:draining_container_id] == "retiring-container"
    end.returns({})

    run_command("boot").tap do |output|
      assert_match(/docker rename app-web-latest .*pre-app-drain.*wait-drain/m, output)
    end
  end

  test "boot skips pre-app-drain when hooks are skipped" do
    stub_running
    stub_drain_hook

    run_command("boot", "--skip-hooks").tap do |output|
      assert_no_match(/pre-app-drain|async-drain|wait-drain/, output)
    end
  end

  test "pre-app-drain requires proxy support before starting a replacement" do
    stub_running
    stub_drain_hook
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :exec, "kamal-proxy", "kamal-proxy", :deploy, "--help").returns("deploy options")
    Kamal::Commands::Hook.any_instance.expects(:env).never

    executions = []
    SSHKit::Backend::Abstract.any_instance.stubs(:execute).with { |*args| executions << args; true }

    error = assert_raises(SSHKit::Runner::ExecuteError) { stderred { run_command("boot") } }

    assert_match "pre-app-drain requires a kamal-proxy release with --async-drain support", error.message
    assert_not executions.any? { |args| args.first == :docker && args.include?(:run) }
    assert_not executions.any? { |args| args.include?("'name=^app-web-123$'") && args.include?(:stop) }
    assert_not KAMAL.holding_lock?
  end

  test "boot does not call pre-app-drain if replacement fails" do
    stub_running
    stub_drain_hook
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with { |*args| args.include?("--async-drain") }
      .raises(SSHKit::Command::Failed.new("replacement is unhealthy"))
    Kamal::Commands::Hook.any_instance.expects(:env).never

    error = assert_raises(SSHKit::Runner::ExecuteError) { stderred { run_command("boot") } }

    assert_match "replacement is unhealthy", error.message
    assert_not KAMAL.holding_lock?
  end

  test "pre-app-drain keeps each host's environment isolated" do
    stub_running
    stub_drain_hook
    keys = %w[ KAMAL_HOSTS KAMAL_ROLE KAMAL_DRAINING_CONTAINER_ID KAMAL_DRAINING_VERSION ]
    original = ENV.slice(*keys)
    contexts = Queue.new
    SSHKit::Backend::Abstract.any_instance.stubs(:execute).returns(true)
    SSHKit::Backend::Abstract.any_instance.stubs(:execute).with do |*args|
      if args == [ ".kamal/hooks/pre-app-drain" ]
        before = ENV.slice(*keys)
        Kernel.sleep(0.01)
        contexts << [ before, ENV.slice(*keys) ]
        true
      else
        false
      end
    end.returns(true)

    run_command("boot", config: :with_proxy_roles, host: nil)

    assert_equal 4, contexts.size
    4.times do
      before, after = contexts.pop
      assert_equal before, after
      assert_equal "123", before["KAMAL_DRAINING_CONTAINER_ID"]
    end
    assert_equal original, ENV.slice(*keys)
  end

  test "boot calls pre-app-drain once per proxied host and role" do
    stub_running
    stub_drain_hook
    seen = []
    Kamal::Commands::Hook.any_instance.stubs(:env).with do |**details|
      seen << details.slice(:hosts, :role, :draining_container_id)
      true
    end.returns({})

    run_command("boot", config: :with_proxy_roles, host: nil)

    assert_equal [
      { hosts: "1.1.1.1", role: "web", draining_container_id: "123" },
      { hosts: "1.1.1.2", role: "web", draining_container_id: "123" },
      { hosts: "1.1.1.3", role: "web2", draining_container_id: "123" },
      { hosts: "1.1.1.4", role: "web2", draining_container_id: "123" }
    ], seen.sort_by { |details| details[:hosts] }
  end

  test "pre-app-drain failure still drains and stops the old container" do
    stub_running
    stub_drain_hook
    fail_hook("pre-app-drain")

    error = assert_raises(SSHKit::Runner::ExecuteError) { run_command("boot") }

    assert_match "Hook `pre-app-drain` failed", error.message
    assert_includes @executions, [ :docker, :exec, "kamal-proxy", "kamal-proxy", :"wait-drain", "drain-123" ]
    assert_includes @executions, [ :docker, :container, :ls, "--all", "--filter", "'name=^app-web-123$'", "--quiet", "|", :xargs, :docker, :stop, { raise_on_non_zero_exit: false } ]
    assert_not @executions.any? { |args| args.include?("'name=^app-web-latest$'") && args.include?(:stop) }
    assert_not KAMAL.holding_lock?
  end

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
    SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
      .with(:docker, :exec, "kamal-proxy", "kamal-proxy", :deploy, "--help").returns("--async-drain")

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

  private
    def stub_drain_hook
      Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(false)
      Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).with("pre-app-drain").returns(true)
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info)
        .with(:docker, :exec, "kamal-proxy", "kamal-proxy", :deploy, "--help").returns("--async-drain")
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).with { |*args| args.include?("--async-drain") }.returns("drain-123")
    end

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
