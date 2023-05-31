require_relative "cli_test_case"

class CliAppTest < CliTestCase
  test "boot" do
    stub_running
    run_command("boot").tap do |output|
      assert_match "docker tag dhh/app:latest dhh/app:latest", output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --hostname 1.1.1.1-[0-9a-f]{12} /, output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
    end
  end

  test "boot will rename if same version is already running" do
    run_command("details") # Preheat MRSK const

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--filter", "name=^app-web-latest$", "--quiet", raise_on_non_zero_exit: false)
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
      .returns("running") # health check

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :ps, "--filter", "label=service=app", "--filter", "label=role=web", "--filter", "status=running", "--filter", "status=restarting", "--latest", "--format", "\"{{.Names}}\"", "|", "grep -oE \"\\-[^-]+$\"", "|", "cut -c 2-", raise_on_non_zero_exit: false)
      .returns("123") # old version

    run_command("boot").tap do |output|
      assert_match /Renaming container .* to .* as already deployed on 1.1.1.1/, output # Rename
      assert_match /docker rename app-web-latest app-web-latest_replaced_[0-9a-f]{16}/, output
      assert_match /docker run --detach --restart unless-stopped --name app-web-latest --hostname 1.1.1.1-[0-9a-f]{12} /, output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "boot uses group strategy when specified" do
    Mrsk::Cli::App.any_instance.stubs(:on).with("1.1.1.1").twice # acquire & release lock
    Mrsk::Cli::App.any_instance.stubs(:on).with([ "1.1.1.1" ]) # tag container

    # Strategy is used when booting the containers
    Mrsk::Cli::App.any_instance.expects(:on).with([ "1.1.1.1" ], in: :groups, limit: 3, wait: 2).with_block_given

    run_command("boot", config: :with_boot_strategy)
  end

  test "boot errors leave lock in place" do
    invoke_options = { "config_file" => "test/fixtures/deploy_simple.yml", "version" => "999" }

    Mrsk::Cli::App.any_instance.expects(:using_version).raises(RuntimeError)

    assert !MRSK.holding_lock?
    assert_raises(RuntimeError) do
      stderred { run_command("boot") }
    end
    assert MRSK.holding_lock?
  end

  test "start" do
    run_command("start").tap do |output|
      assert_match "docker start app-web-999", output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker stop", output
    end
  end

  test "stale_containers" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :ps, "--filter", "label=service=app", "--filter", "label=role=web", "--format", "\"{{.Names}}\"", "|", "grep -oE \"\\-[^-]+$\"", "|", "cut -c 2-", raise_on_non_zero_exit: false)
      .returns("12345678\n87654321")

    run_command("stale_containers").tap do |output|
      assert_match /Detected stale container for role web with version 87654321/, output
    end
  end

  test "stop stale_containers" do
    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :ps, "--filter", "label=service=app", "--filter", "label=role=web", "--format", "\"{{.Names}}\"", "|", "grep -oE \"\\-[^-]+$\"", "|", "cut -c 2-", raise_on_non_zero_exit: false)
      .returns("12345678\n87654321")

    run_command("stale_containers", "--stop").tap do |output|
      assert_match /Stopping stale container for role web with version 87654321/, output
      assert_match /#{Regexp.escape("docker container ls --all --filter name=^app-web-87654321$ --quiet | xargs docker stop")}/, output
    end
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match "docker ps --filter label=service=app --filter label=role=web", output
    end
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match /#{Regexp.escape("docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker stop")}/, output
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
      assert_match "docker run --rm dhh/app:latest ruby -v", output
    end
  end

  test "exec with reuse" do
    run_command("exec", "--reuse", "ruby -v").tap do |output|
      assert_match "docker ps --filter label=service=app --filter status=running --filter status=restarting --latest --format \"{{.Names}}\" | grep -oE \"\\-[^-]+$\" | cut -c 2-", output # Get current version
      assert_match "docker exec app-web-999 ruby -v", output
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
      .with("ssh -t root@1.1.1.1 'docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest| xargs docker logs --timestamps --tail 10 2>&1'")

    assert_match "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --tail 100 2>&1", run_command("logs")
  end

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 'docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --timestamps --tail 10 --follow 2>&1'")

    assert_match "docker ps --quiet --filter label=service=app --filter label=role=web --filter status=running --filter status=restarting --latest | xargs docker logs --timestamps --tail 10 --follow 2>&1", run_command("logs", "--follow")
  end

  test "version" do
    run_command("version").tap do |output|
      assert_match "docker ps --filter label=service=app --filter status=running --filter status=restarting --latest --format \"{{.Names}}\" | grep -oE \"\\-[^-]+$\" | cut -c 2-", output
    end
  end


  test "version through main" do
    stdouted { Mrsk::Cli::Main.start(["app", "version", "-c", "test/fixtures/deploy_with_accessories.yml", "--hosts", "1.1.1.1"]) }.tap do |output|
      assert_match "docker ps --filter label=service=app --filter status=running --filter status=restarting --latest --format \"{{.Names}}\" | grep -oE \"\\-[^-]+$\" | cut -c 2-", output
    end
  end

  private
    def run_command(*command, config: :with_accessories)
      stdouted { Mrsk::Cli::App.start([*command, "-c", "test/fixtures/deploy_#{config}.yml", "--hosts", "1.1.1.1"]) }
    end

    def stub_running
      SSHKit::Backend::Abstract.any_instance.stubs(:capture_with_info).returns("123") # old version

      SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
        .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet", "|", :xargs, :docker, :inspect, "--format", "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'")
        .returns("running") # health check
    end
end
