require_relative "cli_test_case"

class CliAppTest < CliTestCase
  test "boot" do
    # Stub current version fetch
    SSHKit::Backend::Abstract.any_instance.stubs(:capture).returns("123") # old version

    run_command("boot").tap do |output|
      assert_match "docker run --detach --restart unless-stopped", output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
    end
  end

  test "boot will rename if same version is already running" do
    run_command("details") # Preheat MRSK const

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :container, :ls, "--all", "--filter", "name=^app-web-latest$", "--quiet")
      .returns("12345678") # running version

    SSHKit::Backend::Abstract.any_instance.expects(:capture_with_info)
      .with(:docker, :ps, "--filter", "label=service=app", "--filter", "label=role=web", "--format", "\"{{.Names}}\"", "|", "sed 's/-/\\n/g'", "|", "tail -n 1")
      .returns("123") # old version

    run_command("boot").tap do |output|
      assert_match /Renaming container .* to .* as already deployed on 1.1.1.1/, output # Rename
      assert_match /docker rename .* .*/, output
      assert_match "docker run --detach --restart unless-stopped", output
      assert_match "docker container ls --all --filter name=^app-web-123$ --quiet | xargs docker stop", output
    end
  ensure
    Thread.report_on_exception = true
  end

  test "start" do
    run_command("start").tap do |output|
      assert_match "docker start app-web-999", output
    end
  end

  test "stop" do
    run_command("stop").tap do |output|
      assert_match "docker ps --quiet --filter label=service=app --filter label=role=web | xargs docker stop", output
    end
  end

  test "details" do
    run_command("details").tap do |output|
      assert_match "docker ps --filter label=service=app --filter label=role=web", output
    end
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match /#{Regexp.escape("docker ps --quiet --filter label=service=app --filter label=role=web | xargs docker stop")}/, output
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
      assert_match "docker run --rm --label custom=true dhh/app:latest ruby -v", output
    end
  end

  test "exec with reuse" do
    run_command("exec", "--reuse", "ruby -v").tap do |output|
      assert_match "docker ps --filter label=service=app --format \"{{.Names}}\" | sed 's/-/\\n/g' | tail -n 1", output # Get current version
      assert_match "docker exec app-web-999 ruby -v", output
    end
  end

  test "exec with labels" do
    run_command("exec", "ruby -v", "--labels", "hello=world", "abc=def").tap do |output|
      assert_match "docker run --rm --label custom=true --label hello=world --label abc=def dhh/app:latest ruby -v", output
    end
  end

  test "exec with reuse and labels" do
    assert_raise(ArgumentError) do
      run_command("exec", "--reuse", "ruby -v", "--labels", "hello=world", "abc=def")
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
      .with("ssh -t root@1.1.1.1 'docker ps --quiet --filter label=service=app --filter label=role=web | xargs docker logs --timestamps --tail 10 2>&1'")

    assert_match "docker ps --quiet --filter label=service=app --filter label=role=web | xargs docker logs --tail 100 2>&1", run_command("logs")
  end

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.1 'docker ps --quiet --filter label=service=app --filter label=role=web | xargs docker logs --timestamps --tail 10 --follow 2>&1'")

    assert_match "docker ps --quiet --filter label=service=app --filter label=role=web | xargs docker logs --timestamps --tail 10 --follow 2>&1", run_command("logs", "--follow")
  end

  test "version" do
    run_command("version").tap do |output|
      assert_match "docker ps --filter label=service=app --format \"{{.Names}}\" | sed 's/-/\\n/g' | tail -n 1", output
    end
  end


  test "version through main" do
    stdouted { Mrsk::Cli::Main.start(["app", "version", "-c", "test/fixtures/deploy_with_accessories.yml", "--hosts", "1.1.1.1"]) }.tap do |output|
      assert_match "docker ps --filter label=service=app --format \"{{.Names}}\" | sed 's/-/\\n/g' | tail -n 1", output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::App.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml", "--hosts", "1.1.1.1"]) }
    end
end
