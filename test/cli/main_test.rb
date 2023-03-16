require_relative "cli_test_case"

class CliMainTest < CliTestCase
  test "setup" do
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:server:bootstrap")
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:accessory:boot", [ "all" ])
    Mrsk::Cli::Main.any_instance.expects(:deploy)

    run_command("setup")
  end

  test "deploy" do
    invoke_options = { "config_file" => "test/fixtures/deploy_with_accessories.yml", "skip_broadcast" => false, "skip_push" => false }

    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:server:bootstrap", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:registry:login", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:build:deliver", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:traefik:boot", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:healthcheck:perform", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:app:boot", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:prune:all", [], invoke_options)

    run_command("deploy").tap do |output|
      assert_match /Ensure curl and Docker are installed/, output
      assert_match /Log into image registry/, output
      assert_match /Build and push app image/, output
      assert_match /Ensure Traefik is running/, output
      assert_match /Ensure app can pass healthcheck/, output
      assert_match /Prune old containers and images/, output
    end
  end

  test "deploy with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_with_accessories.yml", "skip_broadcast" => false, "skip_push" => true }

    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:server:bootstrap", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:registry:login", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:build:pull", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:traefik:boot", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:healthcheck:perform", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:app:boot", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:prune:all", [], invoke_options)

    run_command("deploy", "--skip_push").tap do |output|
      assert_match /Ensure curl and Docker are installed/, output
      assert_match /Log into image registry/, output
      assert_match /Pull app image/, output
      assert_match /Ensure Traefik is running/, output
      assert_match /Ensure app can pass healthcheck/, output
      assert_match /Prune old containers and images/, output
    end
  end

  test "redeploy" do
    invoke_options = { "config_file" => "test/fixtures/deploy_with_accessories.yml", "skip_broadcast" => false, "skip_push" => false}

    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:build:deliver", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:healthcheck:perform", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:app:boot", [], invoke_options)

    run_command("redeploy").tap do |output|
      assert_match /Build and push app image/, output
      assert_match /Ensure app can pass healthcheck/, output
    end
  end

  test "redeploy with skip_push" do
    invoke_options = { "config_file" => "test/fixtures/deploy_with_accessories.yml", "skip_broadcast" => false, "skip_push" => true }

    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:build:pull", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:healthcheck:perform", [], invoke_options)
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:app:boot", [], invoke_options)

    run_command("redeploy", "--skip_push").tap do |output|
      assert_match /Pull app image/, output
      assert_match /Ensure app can pass healthcheck/, output
    end
  end

  test "rollback bad version" do
    run_command("details") # Preheat MRSK const

    run_command("rollback", "nonsense").tap do |output|
      assert_match /docker container ls --all --filter label=service=app --format '{{ .Names }}'/, output
      assert_match /The app version 'nonsense' is not available as a container/, output
    end
  end

  test "rollback good version" do
    Mrsk::Cli::Main.any_instance.stubs(:container_name_available?).returns(true)

    run_command("rollback", "123").tap do |output|
      assert_match /Start version 123/, output
      assert_match /docker ps -q --filter label=service=app | xargs docker stop/, output
      assert_match /docker start app-123/, output
    end
  end

  test "details" do
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:traefik:details")
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:app:details")
    Mrsk::Cli::Main.any_instance.expects(:invoke).with("mrsk:cli:accessory:details", [ "all" ])

    run_command("details")
  end

  test "audit" do
    run_command("audit").tap do |output|
      assert_match /tail -n 50 mrsk-app-audit.log on 1.1.1.1/, output
      assert_match /App Host: 1.1.1.1/, output
      assert_match /tail -n 50 mrsk-app-audit.log on 1.1.1.2/, output
      assert_match /App Host: 1.1.1.2/, output
    end
  end

  test "config" do
    run_command("config").tap do |output|
      config = YAML.load(output)

      assert_equal ["web"], config[:roles]
      assert_equal ["1.1.1.1", "1.1.1.2"], config[:hosts]
      assert_equal "999", config[:version]
      assert_equal "dhh/app", config[:repository]
      assert_equal "dhh/app:999", config[:absolute_image]
      assert_equal "app-999", config[:service_with_version]
    end
  end

  test "init" do
    Pathname.any_instance.expects(:exist?).returns(false).twice
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)

    run_command("init").tap do |output|
      assert_match /Created configuration file in config\/deploy.yml/, output
      assert_match /Created \.env file/, output
    end
  end

  test "init with existing config" do
    Pathname.any_instance.expects(:exist?).returns(true).twice

    run_command("init").tap do |output|
      assert_match /Config file already exists in config\/deploy.yml \(remove first to create a new one\)/, output
    end
  end

  test "init with bundle option" do
    Pathname.any_instance.expects(:exist?).returns(false).times(3)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)

    run_command("init", "--bundle").tap do |output|
      assert_match /Created configuration file in config\/deploy.yml/, output
      assert_match /Created \.env file/, output
      assert_match /Adding MRSK to Gemfile and bundle/, output
      assert_match /bundle add mrsk/, output
      assert_match /bundle binstubs mrsk/, output
      assert_match /Created binstub file in bin\/mrsk/, output
    end
  end

  test "init with bundle option and existing binstub" do
    Pathname.any_instance.expects(:exist?).returns(true).times(3)
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp_r)

    run_command("init", "--bundle").tap do |output|
      assert_match /Config file already exists in config\/deploy.yml \(remove first to create a new one\)/, output
      assert_match /Binstub already exists in bin\/mrsk \(remove first to create a new one\)/, output
    end
  end

  test "envify" do
    File.expects(:read).with(".env.erb").returns("HELLO=<%= 'world' %>")
    File.expects(:write).with(".env", "HELLO=world", perm: 0600)

    run_command("envify")
  end

  test "envify with destination" do
    File.expects(:read).with(".env.staging.erb").returns("HELLO=<%= 'world' %>")
    File.expects(:write).with(".env.staging", "HELLO=world", perm: 0600)

    run_command("envify", "-d", "staging")
  end

  test "remove with confirmation" do
    run_command("remove", "-y").tap do |output|
      assert_match /docker container stop traefik/, output
      assert_match /docker container prune --force --filter label=org.opencontainers.image.title=Traefik/, output
      assert_match /docker image prune --all --force --filter label=org.opencontainers.image.title=Traefik/, output

      assert_match /docker ps --quiet --filter label=service=app | xargs docker stop/, output
      assert_match /docker container prune --force --filter label=service=app/, output
      assert_match /docker image prune --all --force --filter label=service=app/, output

      assert_match /docker container stop app-mysql/, output
      assert_match /docker container prune --force --filter label=service=app-mysql/, output
      assert_match /docker image prune --all --force --filter label=service=app-mysql/, output
      assert_match /rm -rf app-mysql/, output

      assert_match /docker container stop app-redis/, output
      assert_match /docker container prune --force --filter label=service=app-redis/, output
      assert_match /docker image prune --all --force --filter label=service=app-redis/, output
      assert_match /rm -rf app-redis/, output

      assert_match /docker logout/, output
    end
  end

  test "version" do
    version = stdouted { Mrsk::Cli::Main.new.version }
    assert_equal Mrsk::VERSION, version
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Main.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
