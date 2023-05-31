require_relative "cli_test_case"

class CliBuildTest < CliTestCase
  test "deliver" do
    Mrsk::Cli::Build.any_instance.expects(:push)
    Mrsk::Cli::Build.any_instance.expects(:pull)

    run_command("deliver")
  end

  test "push" do
    Mrsk::Commands::Hook.any_instance.stubs(:hook_exists?).returns(true)
    hook_variables = { version: 999, service_version: "app@999", hosts: "1.1.1.1,1.1.1.2,1.1.1.3,1.1.1.4", command: "build", subcommand: "push" }

    run_command("push").tap do |output|
      assert_hook_ran "pre-build", output, **hook_variables
      assert_match /docker --version && docker buildx version/, output
      assert_match /docker buildx build --push --platform linux\/amd64,linux\/arm64 --builder mrsk-app-multiarch -t dhh\/app:999 -t dhh\/app:latest --label service="app" --file Dockerfile \. as .*@localhost/, output
    end
  end

  test "push without builder" do
    stub_locking
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, "--version", "&&", :docker, :buildx, "version")

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*args| args[0..1] == [:docker, :buildx] }
      .raises(SSHKit::Command::Failed.new("no builder"))
      .then
      .returns(true)

    run_command("push").tap do |output|
      assert_match /Missing compatible builder, so creating a new one first/, output
    end
  end

  test "push with no buildx plugin" do
    stub_locking
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, "--version", "&&", :docker, :buildx, "version")
      .raises(SSHKit::Command::Failed.new("no buildx"))

    Mrsk::Commands::Builder.any_instance.stubs(:native_and_local?).returns(false)
    assert_raises(Mrsk::Cli::Build::BuildError) { run_command("push") }
  end

  test "push pre-build hook failure" do
    fail_hook("pre-build")

    assert_raises(Mrsk::Cli::HookError) { run_command("push") }

    assert @executions.none? { |args| args[0..2] == [:docker, :buildx, :build] }
  end

  test "pull" do
    run_command("pull").tap do |output|
      assert_match /docker image rm --force dhh\/app:999/, output
      assert_match /docker pull dhh\/app:999/, output
    end
  end

  test "create" do
    run_command("create").tap do |output|
      assert_match /docker buildx create --use --name mrsk-app-multiarch/, output
    end
  end

  test "create with error" do
    stub_locking
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |arg| arg == :docker }
      .raises(SSHKit::Command::Failed.new("stderr=error"))

    run_command("create").tap do |output|
      assert_match /Couldn't create remote builder: error/, output
    end
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match /docker buildx rm mrsk-app-multiarch/, output
    end
  end

  test "details" do
    SSHKit::Backend::Abstract.any_instance.stubs(:capture)
      .with(:docker, :context, :ls, "&&", :docker, :buildx, :ls)
      .returns("docker builder info")

    run_command("details").tap do |output|
      assert_match /Builder: multiarch/, output
      assert_match /docker builder info/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Build.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end

    def stub_dependency_checks
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with(:docker, "--version", "&&", :docker, :buildx, "version")
      SSHKit::Backend::Abstract.any_instance.stubs(:execute)
        .with { |*args| args[0..1] == [:docker, :buildx] }
    end
end
