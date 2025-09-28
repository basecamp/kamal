require_relative "cli_test_case"

class CliAliasTest < CliTestCase
  test "alias with aliases" do
    run_command("alias", config_file: "deploy_with_aliases").tap do |output|
      assert_match(/info\s+details/, output)
      assert_match(/console\s+app exec --reuse -p -r console "bin\/console"/, output)
      assert_match(/exec\s+app exec --reuse -p -r console/, output)
      assert_match(/rails\s+app exec --reuse -p -r console rails/, output)
      assert_match(/primary_details\s+details -p/, output)
    end
  end

  test "alias without aliases" do
    run_command("alias", config_file: "deploy_simple").tap do |output|
      assert_match(/No aliases configured/, output)
    end
  end

  test "alias with destination" do
    run_command("alias", "-d", "elsewhere", config_file: "deploy").tap do |output|
      assert_match(/other_config\s+config -c config\/deploy2.yml/, output)
    end
  end

  private
    def run_command(*command, config_file: "deploy_simple")
      with_argv([ *command, "-c", "test/fixtures/#{config_file}.yml" ]) do
        stdouted { Kamal::Cli::Main.start }
      end
    end
end
