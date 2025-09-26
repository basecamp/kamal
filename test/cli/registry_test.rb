require_relative "cli_test_case"

class CliRegistryTest < CliTestCase
  test "setup" do
    run_command("setup").tap do |output|
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] as .*@localhost/, output
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] on 1.1.1.\d/, output
    end
  end

  test "setup skip local" do
    run_command("setup", "-L").tap do |output|
      assert_no_match /docker login -u \[REDACTED\] -p \[REDACTED\] as .*@localhost/, output
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] on 1.1.1.\d/, output
    end
  end

  test "setup skip remote" do
    run_command("setup", "-R").tap do |output|
      assert_match /docker login -u \[REDACTED\] -p \[REDACTED\] as .*@localhost/, output
      assert_no_match /docker login -u \[REDACTED\] -p \[REDACTED\] on 1.1.1.\d/, output
    end
  end

  test "remove" do
    run_command("remove").tap do |output|
      assert_match /docker logout as .*@localhost/, output
      assert_match /docker logout on 1.1.1.\d/, output
    end
  end

  test "remove skip local" do
    run_command("remove", "-L").tap do |output|
      assert_no_match /docker logout as .*@localhost/, output
      assert_match /docker logout on 1.1.1.\d/, output
    end
  end

  test "remove skip remote" do
    run_command("remove", "-R").tap do |output|
      assert_match /docker logout as .*@localhost/, output
      assert_no_match /docker logout on 1.1.1.\d/, output
    end
  end

  test "setup with no docker" do
    stub_setup
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, "--version", "&&", :docker, :buildx, "version")
      .raises(SSHKit::Command::Failed.new("command not found"))

    assert_raises(Kamal::Cli::DependencyError) { run_command("setup") }
  end

  test "allow remote login with no docker" do
    stub_setup
    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with(:docker, "--version", "&&", :docker, :buildx, "version")
      .raises(SSHKit::Command::Failed.new("command not found"))

    SSHKit::Backend::Abstract.any_instance.stubs(:execute)
      .with { |*args| args[0..1] == [ :docker, :login ] }

    assert_nothing_raised { run_command("setup", "--skip-local") }
  end

  test "setup local registry" do
    run_command("setup", fixture: :with_local_registry).tap do |output|
      assert_match /docker start kamal-docker-registry || docker run --detach -p 127.0.0.1:5000:5000 --name kamal-docker-registry registry:2 as .*@localhost/, output
    end
  end

  test "remove local registry" do
    run_command("remove", fixture: :with_local_registry).tap do |output|
      assert_match /docker stop kamal-docker-registry && docker rm kamal-docker-registry as .*@localhost/, output
    end
  end

  private
    def run_command(*command, fixture: :with_accessories)
      stdouted { Kamal::Cli::Registry.start([ *command, "-c", "test/fixtures/deploy_#{fixture}.yml" ]) }
    end
end
