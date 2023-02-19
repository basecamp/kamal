require_relative "cli_test_case"

class CliMainTest < CliTestCase
  test "version" do
    version = stdouted { Mrsk::Cli::Main.new.version }
    assert_equal Mrsk::VERSION, version
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
      assert_match /Stop current version, then start version 123/, output
      assert_match /docker ps -q --filter label=service=app | xargs docker stop/, output
      assert_match /docker start app-123/, output
    end
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

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Main.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
