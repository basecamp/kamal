require_relative "cli_test_case"

class CliMainTest < CliTestCase
  setup { @original_env = ENV.to_h.dup }
  teardown { ENV.clear; ENV.update @original_env }

  test "setup" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:server:bootstrap", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:accessory:boot", [ "all" ], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:deploy)

    run_command("setup").tap do |output|
      assert_match /Ensure Docker is installed.../, output
    end
  end

  test "setup with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:server:bootstrap", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:accessory:boot", [ "all" ], invoke_options)
    # deploy
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:pull", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    run_command("setup", "--skip_push").tap do |output|
      assert_match /Ensure Docker is installed.../, output
      # deploy
      assert_match /Acquiring the deploy lock/, output
      assert_match /Log into image registry/, output
      assert_match /Pull app image/, output
      assert_match /Ensure kamal-proxy is running/, output
      assert_match /Detect stale containers/, output
      assert_match /Prune old containers and images/, output
      assert_match /Releasing the deploy lock/, output
    end
  end

  test "deploy" do
    with_test_secrets("secrets" => "DB_PASSWORD=secret") do
      invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false, "verbose" => true }

      Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: false))
      Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:deliver", [], invoke_options)
      Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:boot", [], invoke_options)
      Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
      Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
      Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

      Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
      hook_variables = { version: 999, service_version: "app@999", hosts: "1.1.1.1,1.1.1.2", command: "deploy" }

      run_command("deploy", "--verbose").tap do |output|
        assert_hook_ran "pre-connect", output, **hook_variables
        assert_match /Log into image registry/, output
        assert_match /Build and push app image/, output
        assert_hook_ran "pre-deploy", output, **hook_variables, secrets: true
        assert_match /Ensure kamal-proxy is running/, output
        assert_match /Detect stale containers/, output
        assert_match /Prune old containers and images/, output
        assert_hook_ran "post-deploy", output, **hook_variables, runtime: true, secrets: true
      end
    end
  end

  test "deploy with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:pull", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    run_command("deploy", "--skip_push").tap do |output|
      assert_match /Acquiring the deploy lock/, output
      assert_match /Log into image registry/, output
      assert_match /Pull app image/, output
      assert_match /Ensure kamal-proxy is running/, output
      assert_match /Detect stale containers/, output
      assert_match /Prune old containers and images/, output
      assert_match /Releasing the deploy lock/, output
    end
  end

  test "deploy when locked" do
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
    Dir.stubs(:chdir)

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*args| args == [ :mkdir, "-p", ".kamal/apps/app" ] }

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*arg| arg[0..1] == [ :mkdir, ".kamal/lock-app" ] }
      .raises(RuntimeError, "mkdir: cannot create directory ‘kamal/lock-app’: File exists")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_debug)
      .with(:stat, ".kamal/lock-app", ">", "/dev/null", "&&", :cat, ".kamal/lock-app/details", "|", :base64, "-d")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:git, "-C", anything, :"rev-parse", :HEAD)
      .returns(Kamal::Git.revision)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:git, "-C", anything, :status, "--porcelain")
      .returns("")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :info, "--format '{{index .RegistryConfig.Mirrors 0}}'")
      .returns("")
      .at_least_once

    assert_raises(Kamal::Cli::LockError) do
      run_command("deploy")
    end
  end

  test "deploy error when locking" do
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
    Dir.stubs(:chdir)

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*args| args == [ :mkdir, "-p", ".kamal/apps/app" ] }

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*arg| arg[0..1] == [ :mkdir, ".kamal/lock-app" ] }
      .raises(SocketError, "getaddrinfo: nodename nor servname provided, or not known")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:git, "-C", anything, :"rev-parse", :HEAD)
      .returns(Kamal::Git.revision)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:git, "-C", anything, :status, "--porcelain")
      .returns("")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :info, "--format '{{index .RegistryConfig.Mirrors 0}}'")
      .returns("")
      .at_least_once

    assert_raises(SSHKit::Runner::ExecuteError) do
      run_command("deploy")
    end
  end

  test "deploy errors during outside section leave remove lock" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false, :skip_local => false }

    Kamal::Cli::Main.any_instance.expects(:invoke)
      .with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: false))
      .raises(RuntimeError)

    assert_not KAMAL.holding_lock?
    assert_raises(RuntimeError) do
      stderred { run_command("deploy") }
    end
    assert_not KAMAL.holding_lock?
  end

  test "deploy with skipped hooks" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => true }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: false))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:deliver", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    run_command("deploy", "--skip_hooks") do
      assert_no_match /Running the post-deploy hook.../, output
    end
  end

  test "deploy with missing secrets" do
    invoke_options = { "config_file" => "test/fixtures/deploy_with_secrets.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: false))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:deliver", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    run_command("deploy", config_file: "deploy_with_secrets")
  end

  test "redeploy" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false, "verbose" => true }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:deliver", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)

    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)

    hook_variables = { version: 999, service_version: "app@999", hosts: "1.1.1.1,1.1.1.2", command: "redeploy" }

    run_command("redeploy", "--verbose").tap do |output|
      assert_hook_ran "pre-connect", output, **hook_variables
      assert_match /Build and push app image/, output
      assert_hook_ran "pre-deploy", output, **hook_variables
      assert_match /Running the pre-deploy hook.../, output
      assert_hook_ran "post-deploy", output, **hook_variables, runtime: true
    end
  end

  test "redeploy with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:pull", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)

    run_command("redeploy", "--skip_push").tap do |output|
      assert_match /Pull app image/, output
    end
  end

  test "rollback bad version" do
    Thread.report_on_exception = false

    run_command("details") # Preheat Kamal const

    run_command("rollback", "nonsense").tap do |output|
      assert_match /docker container ls --all --filter name=\^app-web-nonsense\$ --quiet/, output
      assert_match /The app version 'nonsense' is not available as a container/, output
    end
  end

  test "rollback good version" do
    Object.any_instance.stubs(:sleep)
    [ "web", "workers" ].each do |role|
      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:docker, :container, :ls, "--all", "--filter", "name=^app-#{role}-123$", "--quiet", raise_on_non_zero_exit: false)
        .returns("").at_least_once
      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:docker, :container, :ls, "--all", "--filter", "name=^app-#{role}-123$", "--quiet")
        .returns("version-to-rollback\n").at_least_once
      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=#{role} --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=#{role} --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-#{role}-}; done", raise_on_non_zero_exit: false)
        .returns("version-to-rollback\n").at_least_once
    end

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-workers-123$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # health check

    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    hook_variables = { version: 123, service_version: "app@123", hosts: "1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4", command: "rollback" }

    run_command("rollback", "--verbose", "123", config_file: "deploy_with_accessories").tap do |output|
      assert_hook_ran "pre-deploy", output, **hook_variables
      assert_match "docker tag dhh/app:123 dhh/app:latest", output
      assert_match "docker run --detach --restart unless-stopped --name app-web-123", output
      assert_match "docker container ls --all --filter name=^app-web-version-to-rollback$ --quiet | xargs docker stop", output, "Should stop the container that was previously running"
      assert_hook_ran "post-deploy", output, **hook_variables, runtime: true
    end
  end

  test "rollback without old version" do
    Kamal::Cli::Main.any_instance.stubs(:container_available?).returns(true)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet", raise_on_non_zero_exit: false)
      .returns("").at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet")
      .returns("123").at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=destination= --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("").at_least_once

    run_command("rollback", "123").tap do |output|
      assert_match "docker run --detach --restart unless-stopped --name app-web-123", output
      assert_no_match "docker stop", output
    end
  end

  test "details" do
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:details")
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:details")
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:accessory:details", [ "all" ])

    run_command("details")
  end

  test "audit" do
    run_command("audit").tap do |output|
      assert_match %r{tail -n 50 \.kamal/app-audit.log on 1.1.1.1}, output
      assert_match /App Host: 1.1.1.1/, output
    end
  end

  test "config" do
    run_command("config", config_file: "deploy_simple").tap do |output|
      config = YAML.load(output)

      assert_equal [ "web" ], config[:roles]
      assert_equal [ "1.1.1.1", "1.1.1.2" ], config[:hosts]
      assert_equal "999", config[:version]
      assert_equal "dhh/app", config[:repository]
      assert_equal "dhh/app:999", config[:absolute_image]
      assert_equal "app-999", config[:service_with_version]
    end
  end

  test "config with roles" do
    run_command("config", config_file: "deploy_with_roles").tap do |output|
      config = YAML.load(output)

      assert_equal [ "web", "workers" ], config[:roles]
      assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], config[:hosts]
      assert_equal "999", config[:version]
      assert_equal "registry.digitalocean.com/dhh/app", config[:repository]
      assert_equal "registry.digitalocean.com/dhh/app:999", config[:absolute_image]
      assert_equal "app-999", config[:service_with_version]
    end
  end

  test "config with primary web role override" do
    run_command("config", config_file: "deploy_primary_web_role_override").tap do |output|
      config = YAML.load(output)

      assert_equal [ "web_chicago", "web_tokyo" ], config[:roles]
      assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], config[:hosts]
      assert_equal "1.1.1.3", config[:primary_host]
    end
  end

  test "config with destination" do
    run_command("config", "-d", "world", config_file: "deploy_for_dest").tap do |output|
      config = YAML.load(output)

      assert_equal [ "web" ], config[:roles]
      assert_equal [ "1.1.1.1", "1.1.1.2" ], config[:hosts]
      assert_equal "999", config[:version]
      assert_equal "registry.digitalocean.com/dhh/app", config[:repository]
      assert_equal "registry.digitalocean.com/dhh/app:999", config[:absolute_image]
      assert_equal "app-999", config[:service_with_version]
    end
  end

  test "init" do
    in_dummy_git_repo do
      run_command("init").tap do |output|
        assert_match "Created configuration file in config/deploy.yml", output
        assert_match "Created .kamal/secrets file", output
      end

      assert_file "config/deploy.yml", "service: my-app"
      assert_file ".kamal/secrets", "KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD"
    end
  end

  test "init with existing config" do
    in_dummy_git_repo do
      run_command("init")

      run_command("init").tap do |output|
        assert_match /Config file already exists in config\/deploy.yml \(remove first to create a new one\)/, output
        assert_no_match /Added .kamal\/secrets/, output
      end
    end
  end

  test "init with bundle option" do
    in_dummy_git_repo do
      run_command("init", "--bundle").tap do |output|
        assert_match "Created configuration file in config/deploy.yml", output
        assert_match "Created .kamal/secrets file", output
        assert_match /Adding Kamal to Gemfile and bundle/, output
        assert_match /bundle add kamal/, output
        assert_match /bundle binstubs kamal/, output
        assert_match /Created binstub file in bin\/kamal/, output
      end
    end
  end

  test "init with bundle option and existing binstub" do
    Pathname.any_instance.expects(:exist?).returns(true).times(4)
    Pathname.any_instance.stubs(:mkpath)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)
    FileUtils.stubs(:cp)

    run_command("init", "--bundle").tap do |output|
      assert_match /Config file already exists in config\/deploy.yml \(remove first to create a new one\)/, output
      assert_match /Binstub already exists in bin\/kamal \(remove first to create a new one\)/, output
    end
  end

  test "remove with confirmation" do
    run_command("remove", "-y", config_file: "deploy_with_accessories").tap do |output|
      assert_match /docker container stop kamal-proxy/, output
      assert_match /docker container prune --force --filter label=org.opencontainers.image.title=kamal-proxy/, output
      assert_match /docker image prune --all --force --filter label=org.opencontainers.image.title=kamal-proxy/, output

      assert_match /docker ps --quiet --filter label=service=app | xargs docker stop/, output
      assert_match /docker container prune --force --filter label=service=app/, output
      assert_match /docker image prune --all --force --filter label=service=app/, output
      assert_match "/usr/bin/env rm -r .kamal/apps/app", output

      assert_match /docker container stop app-mysql/, output
      assert_match /docker container prune --force --filter label=service=app-mysql/, output
      assert_match /docker image rm --force mysql/, output
      assert_match /rm -rf app-mysql/, output

      assert_match /docker container stop app-redis/, output
      assert_match /docker container prune --force --filter label=service=app-redis/, output
      assert_match /docker image rm --force redis/, output
      assert_match /rm -rf app-redis/, output

      assert_match /docker logout/, output
    end
  end

  test "docs" do
    run_command("docs").tap do |output|
      assert_match "# Kamal Configuration", output
    end
  end

  test "docs subsection" do
    run_command("docs", "accessory").tap do |output|
      assert_match "# Accessories", output
    end
  end

  test "docs unknown" do
    run_command("docs", "foo").tap do |output|
      assert_match "No documentation found for foo", output
    end
  end

  test "version" do
    version = stdouted { Kamal::Cli::Main.new.version }
    assert_equal Kamal::VERSION, version
  end

  test "run an alias for details" do
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:details")
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:details")
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:accessory:details", [ "all" ])

    run_command("info", config_file: "deploy_with_aliases")
  end

  test "run an alias for a console" do
    run_command("console", config_file: "deploy_with_aliases").tap do |output|
      assert_match "docker exec app-console-999 bin/console on 1.1.1.5", output
      assert_match "App Host: 1.1.1.5", output
    end
  end

  test "run an alias for a console overriding role" do
    run_command("console", "-r", "workers", config_file: "deploy_with_aliases").tap do |output|
      assert_match "docker exec app-workers-999 bin/console on 1.1.1.3", output
      assert_match "App Host: 1.1.1.3", output
    end
  end

  test "run an alias for a console passing command" do
    run_command("exec", "bin/job", config_file: "deploy_with_aliases").tap do |output|
      assert_match "docker exec app-console-999 bin/job on 1.1.1.5", output
      assert_match "App Host: 1.1.1.5", output
    end
  end

  test "append to command with an alias" do
    run_command("rails", "db:migrate:status", config_file: "deploy_with_aliases").tap do |output|
      assert_match "docker exec app-console-999 rails db:migrate:status on 1.1.1.5", output
      assert_match "App Host: 1.1.1.5", output
    end
  end

  test "upgrade" do
    invoke_options = { "config_file" => "test/fixtures/deploy_with_accessories.yml", "skip_hooks" => false, "confirmed" => true, "rolling" => false }
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:upgrade", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:accessory:upgrade", [ "all" ], invoke_options)

    run_command("upgrade", "-y", config_file: "deploy_with_accessories").tap do |output|
      assert_match "Upgrading all hosts...", output
      assert_match "Upgraded all hosts", output
    end
  end

  test "upgrade rolling" do
    invoke_options = { "config_file" => "test/fixtures/deploy_with_accessories.yml", "skip_hooks" => false, "confirmed" => true, "rolling" => false }
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:proxy:upgrade", [], invoke_options).times(4)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:accessory:upgrade", [ "all" ], invoke_options).times(3)

    run_command("upgrade", "--rolling", "-y", config_file: "deploy_with_accessories").tap do |output|
      assert_match "Upgrading 1.1.1.1...", output
      assert_match "Upgraded 1.1.1.1", output
      assert_match "Upgrading 1.1.1.2...", output
      assert_match "Upgraded 1.1.1.2", output
      assert_match "Upgrading 1.1.1.3...", output
      assert_match "Upgraded 1.1.1.3", output
      assert_match "Upgrading 1.1.1.4...", output
      assert_match "Upgraded 1.1.1.4", output
    end
  end

  private
    def run_command(*command, config_file: "deploy_simple")
      with_argv([ *command, "-c", "test/fixtures/#{config_file}.yml" ]) do
        stdouted { Kamal::Cli::Main.start }
      end
    end

    def in_dummy_git_repo
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          `git init`
          yield
        end
      end
    end

    def assert_file(file, content)
      assert_match content, File.read(file)
    end
end
