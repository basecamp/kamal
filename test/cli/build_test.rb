require_relative "cli_test_case"

class CliBuildTest < CliTestCase
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
