require "test_helper"

class UtilsTest < ActiveSupport::TestCase
  test "argumentize" do
    assert_equal [ "--label", "foo=\"\\`bar\\`\"", "--label", "baz=\"qux\"", "--label", :quux ], \
      Mrsk::Utils.argumentize("--label", { foo: "`bar`", baz: "qux", quux: nil })
  end

  test "argumentize with redacted" do
    assert_kind_of SSHKit::Redaction, \
      Mrsk::Utils.argumentize("--label", { foo: "bar" }, sensitive: true).last
  end

  test "argumentize_env_with_secrets" do
    ENV.expects(:fetch).with("FOO").returns("secret")

    args = Mrsk::Utils.argumentize_env_with_secrets({ "secret" => [ "FOO" ], "clear" => { BAZ: "qux" } })

    assert_equal [ "-e", "FOO=[REDACTED]", "-e", "BAZ=\"qux\"" ], Mrsk::Utils.redacted(args)
    assert_equal [ "-e", "FOO=\"secret\"", "-e", "BAZ=\"qux\"" ], Mrsk::Utils.unredacted(args)
  end

  test "argumentize_env_with_secrets with optional" do
    ENV.expects(:[]).with("FOO").returns('secret')

    args = Mrsk::Utils.argumentize_env_with_secrets({ "secret" => [ "FOO?" ], "clear" => { BAZ: "qux" } })

    assert_equal [ "-e", "FOO=[REDACTED]", "-e", "BAZ=\"qux\"" ], Mrsk::Utils.redacted(args)
    assert_equal [ "-e", "FOO=\"secret\"", "-e", "BAZ=\"qux\"" ], Mrsk::Utils.unredacted(args)
  end

  test "argumentize_env_with_secrets with missing optional" do
    args = Mrsk::Utils.argumentize_env_with_secrets({ "secret" => [ "FOO?" ], "clear" => { BAZ: "qux" } })

    assert_equal [ "-e", "BAZ=\"qux\"" ], Mrsk::Utils.redacted(args)
    assert_equal [ "-e", "BAZ=\"qux\"" ], Mrsk::Utils.unredacted(args)
  end

  test "optionize" do
    assert_equal [ "--foo", "\"bar\"", "--baz", "\"qux\"", "--quux" ], \
      Mrsk::Utils.optionize({ foo: "bar", baz: "qux", quux: true })
  end

  test "optionize with" do
    assert_equal [ "--foo=\"bar\"", "--baz=\"qux\"", "--quux" ], \
      Mrsk::Utils.optionize({ foo: "bar", baz: "qux", quux: true }, with: "=")
  end

  test "no redaction from #to_s" do
    assert_equal "secret", Mrsk::Utils.sensitive("secret").to_s
  end

  test "redact from #inspect" do
    assert_equal "[REDACTED]".inspect, Mrsk::Utils.sensitive("secret").inspect
  end

  test "redact from SSHKit output" do
    assert_kind_of SSHKit::Redaction, Mrsk::Utils.sensitive("secret")
  end

  test "redact from YAML output" do
    assert_equal "--- ! '[REDACTED]'\n", YAML.dump(Mrsk::Utils.sensitive("secret"))
  end

  test "escape_shell_value" do
    assert_equal "\"foo\"", Mrsk::Utils.escape_shell_value("foo")
    assert_equal "\"\\`foo\\`\"", Mrsk::Utils.escape_shell_value("`foo`")

    assert_equal "\"${PWD}\"", Mrsk::Utils.escape_shell_value("${PWD}")
    assert_equal "\"${cat /etc/hostname}\"", Mrsk::Utils.escape_shell_value("${cat /etc/hostname}")
    assert_equal "\"\\${PWD]\"", Mrsk::Utils.escape_shell_value("${PWD]")
    assert_equal "\"\\$(PWD)\"", Mrsk::Utils.escape_shell_value("$(PWD)")
    assert_equal "\"\\$PWD\"", Mrsk::Utils.escape_shell_value("$PWD")

    assert_equal "\"^(https?://)www.example.com/(.*)\\$\"",
      Mrsk::Utils.escape_shell_value("^(https?://)www.example.com/(.*)$")
    assert_equal "\"https://example.com/\\$2\"",
      Mrsk::Utils.escape_shell_value("https://example.com/$2")
  end

  test "uncommitted changes exist" do
    Mrsk::Utils.expects(:`).with("git status --porcelain").returns("M   file\n")
    assert_equal "M   file", Mrsk::Utils.uncommitted_changes
  end

  test "uncommitted changes do not exist" do
    Mrsk::Utils.expects(:`).with("git status --porcelain").returns("")
    assert_equal "", Mrsk::Utils.uncommitted_changes
  end
end
