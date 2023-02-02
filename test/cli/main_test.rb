require_relative "cli_test_case"

class CliMainTest < CliTestCase
  test "version" do
    version = stdouted { Mrsk::Cli::Main.new.version }
    assert_equal Mrsk::VERSION, version
  end
end
