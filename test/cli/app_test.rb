require_relative "cli_test_case"

class CliAppTest < CliTestCase
  test "boot" do
    assert_match /Running docker run -d --restart unless-stopped/, run_command("boot")
  end

  test "boot will reboot if same version is already running" do
    run_command("details") # Preheat MRSK const

    # Prevent expected failures from outputting to terminal
    Thread.report_on_exception = false

    MRSK.app.stubs(:run).raises(SSHKit::Command::Failed.new("already in use")).then.returns([ :docker, :run ])

    run_command("boot").tap do |output|
      assert_match /Rebooting container with same version already deployed/, output # Can't start what's already running
      assert_match /docker ps -q --filter label=service=app \| xargs docker stop/, output # Stop what's running
      assert_match /docker container ls -a -f name=app-999 -q \| xargs docker container rm/, output # Remove old container
      assert_match /docker run/, output # Start new container
    end
  ensure
    Thread.report_on_exception = true
  end

  test "start" do
    run_command("start").tap do |output|
      assert_match /docker start app-999/, output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match /docker ps -q --filter label=service=app \| xargs docker stop/, output
    end
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match /docker ps --filter label=service=app/, output
    end
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match /docker ps -q --filter label=service=app | xargs docker stop/, output
      assert_match /docker container prune -f --filter label=service=app/, output
      assert_match /docker image prune -a -f --filter label=service=app/, output
    end
  end

  test "remove_container" do
    run_command("remove_container", "1234567").tap do |output|
      assert_match /docker container ls -a -f name=app-1234567 -q \| xargs docker container rm/, output
    end
  end

  test "exec" do
    run_command("exec", "ruby -v").tap do |output|
      assert_match /ruby -v/, output
    end
  end

  test "exec with reuse" do
    run_command("exec", "--reuse", "ruby -v").tap do |output|
      assert_match %r[docker ps --filter label=service=app --format \"{{.Names}}\" | sed 's/-/\\n/g' | tail -n 1], output # Get current version
      assert_match %r[docker exec app-999 ruby -v], output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::App.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
