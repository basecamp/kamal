require_relative "cli_test_case"

class CliBuildTest < CliTestCase
  test "deliver" do
    run_command("deliver").tap do |output|
      assert_match /docker buildx build --push --platform linux\/amd64,linux\/arm64 --builder mrsk-app-multiarch -t dhh\/app:999 -t dhh\/app:latest --label service="app" --file Dockerfile \. as .*\@localhost/, output
      assert_match /docker image rm --force dhh\/app:999 on 1\.1\.1\.2/, output
      assert_match /docker pull dhh\/app:999 on 1\.1\.1\.1/, output
    end
  end

  test "deliver without push" do
    run_command("deliver", "--skip-push").tap do |output|
      assert_match /docker image rm --force dhh\/app:999 on 1\.1\.1\.2/, output
      assert_match /docker pull dhh\/app:999 on 1\.1\.1\.1/, output
    end
  end

  test "push" do
    run_command("push").tap do |output|
      assert_match /docker buildx build --push --platform linux\/amd64,linux\/arm64 --builder mrsk-app-multiarch -t dhh\/app:999 -t dhh\/app:latest --label service="app" --file Dockerfile \. as .*\@localhost/, output
    end
  end

  test "pull" do
    run_command("pull").tap do |output|
      assert_match /docker image rm --force dhh\/app:999 on 1\.1\.1\.2/, output
      assert_match /docker pull dhh\/app:999 on 1\.1\.1\.1/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Build.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
