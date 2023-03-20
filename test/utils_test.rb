require "test_helper"

class UtilsTest < ActiveSupport::TestCase
  test "argumentize" do
    assert_equal [ "--label", "foo=\"\\`bar\\`\"", "--label", "baz=\"qux\"", "--label", :quux ], \
      Mrsk::Utils.argumentize("--label", { foo: "`bar`", baz: "qux", quux: nil })
  end

  test "argumentize with redacted" do
    assert_kind_of SSHKit::Redaction, \
      Mrsk::Utils.argumentize("--label", { foo: "bar" }, redacted: true).last
  end

  test "argumentize_env_with_secrets" do
    ENV.expects(:fetch).with("FOO").returns("secret")
    assert_equal [ "-e", "FOO=\"secret\"", "-e", "BAZ=\"qux\"" ], \
      Mrsk::Utils.argumentize_env_with_secrets({ "secret" => [ "FOO" ], "clear" => { BAZ: "qux" } })
  end

  test "optionize" do
    assert_equal [ "--foo", "\"bar\"", "--baz", "\"qux\"", "--quux" ], \
      Mrsk::Utils.optionize({ foo: "bar", baz: "qux", quux: true })
  end

  test "optionize with" do
    assert_equal [ "--foo=\"bar\"", "--baz=\"qux\"", "--quux" ], \
      Mrsk::Utils.optionize({ foo: "bar", baz: "qux", quux: true }, with: "=")
  end

  test "redact" do
    assert_kind_of SSHKit::Redaction, Mrsk::Utils.redact("secret")
    assert_equal "secret", Mrsk::Utils.redact("secret")
  end

  test "escape_shell_value" do
    assert_equal "\"foo\"", Mrsk::Utils.escape_shell_value("foo")
    assert_equal "\"\\`foo\\`\"", Mrsk::Utils.escape_shell_value("`foo`")
  end
end
