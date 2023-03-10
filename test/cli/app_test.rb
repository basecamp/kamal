require_relative "cli_test_case"

class CliAppTest < CliTestCase
  test "boot" do
    # Stub current version fetch
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .returns("999") # new version
      .then
      .returns("123") # old version

    run_command("boot").tap do |output|
      assert_match %r[docker run --detach --restart unless-stopped], output
      assert_match %r[docker container ls --all --filter name=app-web-123 --quiet | xargs docker stop], output
    end
  end

  test "boot will reboot if same version is already running" do
    run_command("details") # Preheat MRSK const

    # Prevent expected failures from outputting to terminal
    Thread.report_on_exception = false

    Mrsk::Commands::App.any_instance.stubs(:run)
      .raises(SSHKit::Command::Failed.new("already in use"))
      .then
      .returns([ :docker, :run ])

    run_command("boot").tap do |output|
      assert_match %r[Rebooting container with same version 999 already deployed], output # Can't start what's already running
      assert_match %r[docker container ls --all --filter name=app-web-999 --quiet | xargs docker stop], output # Stop old running
      assert_match %r[docker container ls --all --filter name=app-web-999 --quiet | xargs docker container rm], output # Remove old container
      assert_match %r[docker run on 1.1.1.1], output # Start new container
    end
  ensure
    Thread.report_on_exception = true
  end

  test "start" do
    run_command("start").tap do |output|
      assert_match %r[docker start app-web-999], output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match %r[docker ps --quiet --filter label=service=app label=role=web | xargs docker stop], output
    end
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match %r[docker ps --filter label=service=app label=role=web], output
    end
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match %r[docker ps --quiet --filter label=service=app label=role=web | xargs docker stop], output
      assert_match %r[docker container prune --force --filter label=service=app], output
      assert_match %r[docker image prune --all --force --filter label=service=app], output
    end
  end

  test "remove_container" do
    run_command("remove_container", "1234567").tap do |output|
      assert_match %r[docker container ls --all --filter name=app-web-1234567 --quiet | xargs docker container rm], output
    end
  end

  test "exec" do
    run_command("exec", "ruby -v").tap do |output|
      assert_match %r[docker run --rm dhh/app:999 ruby -v], output
    end
  end

  test "exec with reuse" do
    run_command("exec", "--reuse", "ruby -v").tap do |output|
      assert_match %r[docker ps --filter label=service=app --format "{{.Names}}" | sed 's/-/\n/g' | tail -n 1], output
      assert_match %r[docker exec app-web-999 ruby -v], output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::App.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml", "--hosts", "1.1.1.1"]) }
    end
end
