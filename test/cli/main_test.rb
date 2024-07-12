require_relative "cli_test_case"

class CliMainTest < CliTestCase
  test "setup" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:server:bootstrap", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:main:envify", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:env:push", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:accessory:boot", [ "all" ], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:deploy)

    run_command("setup").tap do |output|
      assert_match /Ensure Docker is installed.../, output
      assert_match /Evaluate and push env files.../, output
    end
  end

  test "setup with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:server:bootstrap", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:env:push", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:main:envify", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:accessory:boot", [ "all" ], invoke_options)
    # deploy
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:pull", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:traefik:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    run_command("setup", "--skip_push").tap do |output|
      assert_match /Ensure Docker is installed.../, output
      assert_match /Evaluate and push env files.../, output
      # deploy
      assert_match /Acquiring the deploy lock/, output
      assert_match /Log into image registry/, output
      assert_match /Pull app image/, output
      assert_match /Ensure Traefik is running/, output
      assert_match /Detect stale containers/, output
      assert_match /Prune old containers and images/, output
      assert_match /Releasing the deploy lock/, output
    end
  end

  test "deploy" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false, "verbose" => true }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: false))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:deliver", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:traefik:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    Kamal::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    hook_variables = { version: 999, service_version: "app@999", hosts: "1.1.1.1,1.1.1.2", command: "deploy" }

    run_command("deploy", "--verbose").tap do |output|
      assert_hook_ran "pre-connect", output, **hook_variables
      assert_match /Log into image registry/, output
      assert_match /Build and push app image/, output
      assert_hook_ran "pre-deploy", output, **hook_variables
      assert_match /Ensure Traefik is running/, output
      assert_match /Detect stale containers/, output
      assert_match /Prune old containers and images/, output
      assert_hook_ran "post-deploy", output, **hook_variables, runtime: true
    end
  end

  test "deploy with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:pull", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:traefik:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    run_command("deploy", "--skip_push").tap do |output|
      assert_match /Acquiring the deploy lock/, output
      assert_match /Log into image registry/, output
      assert_match /Pull app image/, output
      assert_match /Ensure Traefik is running/, output
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
      .with { |*args| args == [ :mkdir, "-p", ".kamal" ] }

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*args| args == [ :mkdir, "-p", ".kamal/locks" ] }

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*arg| arg[0..1] == [ :mkdir, ".kamal/locks/app" ] }
      .raises(RuntimeError, "mkdir: cannot create directory ‘kamal/locks/app’: File exists")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_debug)
      .with(:stat, ".kamal/locks/app", ">", "/dev/null", "&&", :cat, ".kamal/locks/app/details", "|", :base64, "-d")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:git, "-C", anything, :"rev-parse", :HEAD)
      .returns(Kamal::Git.revision)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:git, "-C", anything, :status, "--porcelain")
      .returns("")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :buildx, :inspect, "kamal-app-multiarch", "> /dev/null")
      .returns("")

    assert_raises(Kamal::Cli::LockError) do
      run_command("deploy")
    end
  end

  test "deploy error when locking" do
    Thread.report_on_exception = false

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
    Dir.stubs(:chdir)

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*args| args == [ :mkdir, "-p", ".kamal" ] }

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*args| args == [ :mkdir, "-p", ".kamal/locks" ] }

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*arg| arg[0..1] == [ :mkdir, ".kamal/locks/app" ] }
      .raises(SocketError, "getaddrinfo: nodename nor servname provided, or not known")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:git, "-C", anything, :"rev-parse", :HEAD)
      .returns(Kamal::Git.revision)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:git, "-C", anything, :status, "--porcelain")
      .returns("")

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :buildx, :inspect, "kamal-app-multiarch", "> /dev/null")
      .returns("")

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
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:traefik:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    run_command("deploy", "--skip_hooks") do
      assert_no_match /Running the post-deploy hook.../, output
    end
  end

  test "deploy without healthcheck if primary host doesn't have traefik" do
    invoke_options = { "config_file" => "test/fixtures/deploy_workers_only.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:healthcheck:perform", [], invoke_options).never

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: false))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:deliver", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:traefik:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:app:boot", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:prune:all", [], invoke_options)

    run_command("deploy", config_file: "deploy_workers_only")
  end

  test "deploy with missing secrets" do
    invoke_options = { "config_file" => "test/fixtures/deploy_with_secrets.yml", "version" => "999", "skip_hooks" => false }

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:registry:login", [], invoke_options.merge(skip_local: false))
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:build:deliver", [], invoke_options)
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:traefik:boot", [], invoke_options)
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
        .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=role=#{role} --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=role=#{role} --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-#{role}-}; done", raise_on_non_zero_exit: false)
        .returns("version-to-rollback\n").at_least_once
      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:docker, :container, :ls, "--all", "--filter", "name=^app-#{role}-123$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
        .returns("running").at_least_once # health check
    end

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :inspect, "-f '{{ range .Mounts }}{{printf \"%s %s\\n\" .Source .Destination}}{{ end }}'", "app-web-version-to-rollback", "|", :awk, "'$2 == \"/tmp/kamal-cord\" {print $1}'", raise_on_non_zero_exit: false)
      .returns("corddirectory").at_least_once # health check

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-version-to-rollback$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("unhealthy").at_least_once # health check

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

    Kamal::Cli::Healthcheck::Poller.stubs(:sleep)

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet", raise_on_non_zero_exit: false)
      .returns("").at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:sh, "-c", "'docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --filter ancestor=$(docker image ls --filter reference=dhh/app:latest --format '\\''{{.ID}}'\\'') ; docker ps --latest --format '\\''{{.Names}}'\\'' --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting'", "|", :head, "-1", "|", "while read line; do echo ${line#app-web-}; done", raise_on_non_zero_exit: false)
      .returns("").at_least_once
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-123$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running").at_least_once # health check

    run_command("rollback", "123").tap do |output|
      assert_match "docker run --detach --restart unless-stopped --name app-web-123", output
      assert_no_match "docker stop", output
    end
  end

  test "details" do
    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:traefik:details")
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
    Pathname.any_instance.expects(:exist?).returns(false).times(3)
    Pathname.any_instance.stubs(:mkpath)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)
    FileUtils.stubs(:cp)

    run_command("init").tap do |output|
      assert_match /Created configuration file in config\/deploy.yml/, output
      assert_match /Created \.env file/, output
    end
  end

  test "init with existing config" do
    Pathname.any_instance.expects(:exist?).returns(true).times(3)

    run_command("init").tap do |output|
      assert_match /Config file already exists in config\/deploy.yml \(remove first to create a new one\)/, output
    end
  end

  test "init with bundle option" do
    Pathname.any_instance.expects(:exist?).returns(false).times(4)
    Pathname.any_instance.stubs(:mkpath)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)
    FileUtils.stubs(:cp)

    run_command("init", "--bundle").tap do |output|
      assert_match /Created configuration file in config\/deploy.yml/, output
      assert_match /Created \.env file/, output
      assert_match /Adding Kamal to Gemfile and bundle/, output
      assert_match /bundle add kamal/, output
      assert_match /bundle binstubs kamal/, output
      assert_match /Created binstub file in bin\/kamal/, output
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

  test "envify" do
    with_test_dot_env_erb(contents: "HELLO=<%= 'world' %>") do
      run_command("envify")
      assert_equal("HELLO=world", File.read(".env"))
    end
  end

  test "envify with blank line trimming" do
    file = <<~EOF
      HELLO=<%= 'world' %>
      <% if true -%>
      KEY=value
      <% end -%>
    EOF

    with_test_dot_env_erb(contents: file) do
      run_command("envify")
      assert_equal("HELLO=world\nKEY=value\n", File.read(".env"))
    end
  end

  test "envify with destination" do
    with_test_dot_env_erb(contents: "HELLO=<%= 'world' %>", file: ".env.world.erb") do
      run_command("envify", "-d", "world", config_file: "deploy_for_dest")
      assert_equal "HELLO=world", File.read(".env.world")
    end
  end

  test "envify with skip_push" do
    Pathname.any_instance.expects(:exist?).returns(true).times(1)
    File.expects(:read).with(".env.erb").returns("HELLO=<%= 'world' %>")
    File.expects(:write).with(".env", "HELLO=world", perm: 0600)

    Kamal::Cli::Main.any_instance.expects(:invoke).with("kamal:cli:env:push").never
    run_command("envify", "--skip-push")
  end

  test "remove with confirmation" do
    run_command("remove", "-y", config_file: "deploy_with_accessories").tap do |output|
      assert_match /docker container stop traefik/, output
      assert_match /docker container prune --force --filter label=org.opencontainers.image.title=Traefik/, output
      assert_match /docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik/, output

      assert_match /docker ps --quiet --filter label=service=app | xargs docker stop/, output
      assert_match /docker container prune --force --filter label=service=app/, output
      assert_match /docker image prune --all --force --filter label=service=app/, output

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

  private
    def run_command(*command, config_file: "deploy_simple")
      stdouted { Kamal::Cli::Main.start([ *command, "-c", "test/fixtures/#{config_file}.yml" ]) }
    end

    def with_test_dot_env_erb(contents:, file: ".env.erb")
      Dir.mktmpdir do |dir|
        fixtures_dup = File.join(dir, "test")
        FileUtils.mkdir_p(fixtures_dup)
        FileUtils.cp_r("test/fixtures/", fixtures_dup)

        Dir.chdir(dir) do
          File.write(file, contents)
          yield
        end
      end
    end
end
