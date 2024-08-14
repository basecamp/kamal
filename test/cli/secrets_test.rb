require_relative "cli_test_case"

class CliSecretsTest < CliTestCase
  test "login" do
    assert_equal "LOGIN_TOKEN", run_command("login", "--adapter", "test")
  end

  test "login failed" do
    assert_raises("Boom!") do
      run_command("login", "--adapter", "test", "--adapter-options", "boom:true")
    end
  end

  test "fetch" do
    assert_equal "oof", run_command("fetch", "foo", "--adapter", "test")
  end

  test "fetch failed" do
    assert_raises("Boom!") do
      run_command("fetch", "foo", "--adapter", "test", "--adapter-options", "boom:true")
    end
  end

  test "fetch_all" do
    assert_equal \
      "\\{\\\"foo\\\":\\\"oof\\\",\\\"bar\\\":\\\"rab\\\",\\\"baz\\\":\\\"zab\\\"\\}",
      run_command("fetch_all", "foo", "bar", "baz", "--adapter", "test")
  end

  test "fetch_all failed" do
    assert_raises("Boom!") do
      assert_equal \
        "\\{\\\"foo\\\":\\\"oof\\\",\\\"bar\\\":\\\"rab\\\",\\\"baz\\\":\\\"zab\\\"\\}",
        run_command("fetch_all", "foo", "bar", "baz", "--adapter", "test", "--adapter-options", "boom:true")
    end
  end

  test "extract" do
    assert_equal "oof", run_command("extract", "foo", "{\"foo\":\"oof\", \"bar\":\"rab\", \"baz\":\"zab\"}")
  end

  private
    def run_command(*command)
      stdouted { Kamal::Cli::Secrets.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
