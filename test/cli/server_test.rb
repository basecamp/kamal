require_relative "cli_test_case"

class CliServerTest < CliTestCase
  test "bootstrap" do
    run_command("bootstrap").tap do |output|
      assert_match /which curl/, output
      assert_match /which docker/, output
      assert_match /apt-get update -y && apt-get install curl docker.io -y/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Server.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
