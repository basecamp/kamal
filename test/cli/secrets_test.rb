require_relative "cli_test_case"

class CliSecretsTest < CliTestCase
  test "fetch" do
    assert_equal \
      "{\"foo\":\"oof\",\"bar\":\"rab\",\"baz\":\"zab\"}",
      run_command("fetch", "foo", "bar", "baz", "--account", "myaccount", "--adapter", "test")
  end

  test "extract" do
    assert_equal "oof", run_command("extract", "foo", "{\"foo\":\"oof\", \"bar\":\"rab\", \"baz\":\"zab\"}")
  end

  test "extract match from end" do
    assert_equal "oof", run_command("extract", "foo", "{\"abc/foo\":\"oof\", \"bar\":\"rab\", \"baz\":\"zab\"}")
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Secrets.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
