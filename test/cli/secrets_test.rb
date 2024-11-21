require_relative "cli_test_case"

class CliSecretsTest < CliTestCase
  test "fetch" do
    assert_equal \
      "\\{\\\"foo\\\":\\\"oof\\\",\\\"bar\\\":\\\"rab\\\",\\\"baz\\\":\\\"zab\\\"\\}",
      run_command("fetch", "foo", "bar", "baz", "--account", "myaccount", "--adapter", "test")
  end

  test "fetch missing --acount" do
    assert_equal \
      "No value provided for required options '--account'",
      run_command("fetch", "foo", "bar", "baz", "--adapter", "test")
  end

  test "fetch without required --account" do
    assert_equal \
      "\\{\\\"foo\\\":\\\"oof\\\",\\\"bar\\\":\\\"rab\\\",\\\"baz\\\":\\\"zab\\\"\\}",
      run_command("fetch", "foo", "bar", "baz", "--adapter", "test_optional_account")
  end

  test "extract" do
    assert_equal "oof", run_command("extract", "foo", "{\"foo\":\"oof\", \"bar\":\"rab\", \"baz\":\"zab\"}")
  end

  test "extract match from end" do
    assert_equal "oof", run_command("extract", "foo", "{\"abc/foo\":\"oof\", \"bar\":\"rab\", \"baz\":\"zab\"}")
  end

  test "print" do
    with_test_secrets("secrets" => "SECRET1=ABC\nSECRET2=${SECRET1}DEF\n") do
      assert_equal "SECRET1=ABC\nSECRET2=ABCDEF", run_command("print")
    end
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Secrets.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
