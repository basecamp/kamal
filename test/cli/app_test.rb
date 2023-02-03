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

  test "reboot to default version" do
    run_command("reboot").tap do |output|
      assert_match /docker ps --filter label=service=app/, output # Find current container
      assert_match /docker stop/, output # Stop old container
      assert_match /docker container rm/, output # Remove old container
      assert_match /docker run -d --restart unless-stopped .* dhh\/app:999/, output # Start new container
    end
  end

  test "reboot to specific version" do
    run_command("reboot", "--version", "456").tap do |output|
      assert_match /docker run -d --restart unless-stopped .* dhh\/app:456/, output
    end
  end

  test "remove_container" do
    run_command("remove_container", "1234567").tap do |output|
      assert_match /docker container ls -a -f name=app-1234567 -q | docker container rm/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::App.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
