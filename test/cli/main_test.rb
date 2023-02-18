require_relative "cli_test_case"

class CliMainTest < CliTestCase
  test "version" do
    version = stdouted { Mrsk::Cli::Main.new.version }
    assert_equal Mrsk::VERSION, version
  end

  test "rollback bad version" do
    run_command("details") # Preheat MRSK const

    run_command("rollback", "nonsense").tap do |output|
      assert_match /docker container ls -a --filter label=service=app --format '{{ .Names }}'/, output
      assert_match /The app version 'nonsense' is not available as a container/, output
    end
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Main.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
