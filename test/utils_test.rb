require "test_helper"

class UtilsTest < ActiveSupport::TestCase
  test "argumentize" do
    assert_equal [ "--label", "foo=\"\\`bar\\`\"", "--label", "baz=\"qux\"", "--label", :quux, "--label", "quuz=false" ], \
      Kamal::Utils.argumentize("--label", { foo: "`bar`", baz: "qux", quux: nil, quuz: false })
  end

  test "argumentize with redacted" do
    assert_kind_of SSHKit::Redaction, \
      Kamal::Utils.argumentize("--label", { foo: "bar" }, sensitive: true).last
  end

  test "optionize" do
    assert_equal [ "--foo", "\"bar\"", "--baz", "\"qux\"", "--quux" ], \
      Kamal::Utils.optionize({ foo: "bar", baz: "qux", quux: true })
  end

  test "optionize with" do
    assert_equal [ "--foo=\"bar\"", "--baz=\"qux\"", "--quux" ], \
      Kamal::Utils.optionize({ foo: "bar", baz: "qux", quux: true }, with: "=")
  end

  test "no redaction from #to_s" do
    assert_equal "secret", Kamal::Utils.sensitive("secret").to_s
  end

  test "redact from #inspect" do
    assert_equal "[REDACTED]".inspect, Kamal::Utils.sensitive("secret").inspect
  end

  test "redact from SSHKit output" do
    assert_kind_of SSHKit::Redaction, Kamal::Utils.sensitive("secret")
  end

  test "redact from YAML output" do
    assert_equal "--- ! '[REDACTED]'\n", YAML.dump(Kamal::Utils.sensitive("secret"))
  end

  test "escape_shell_value" do
    assert_equal "\"foo\"", Kamal::Utils.escape_shell_value("foo")
    assert_equal "\"\\`foo\\`\"", Kamal::Utils.escape_shell_value("`foo`")

    assert_equal "\"${PWD}\"", Kamal::Utils.escape_shell_value("${PWD}")
    assert_equal "\"${cat /etc/hostname}\"", Kamal::Utils.escape_shell_value("${cat /etc/hostname}")
    assert_equal "\"\\${PWD]\"", Kamal::Utils.escape_shell_value("${PWD]")
    assert_equal "\"\\$(PWD)\"", Kamal::Utils.escape_shell_value("$(PWD)")
    assert_equal "\"\\$PWD\"", Kamal::Utils.escape_shell_value("$PWD")

    assert_equal "\"^(https?://)www.example.com/(.*)\\$\"",
      Kamal::Utils.escape_shell_value("^(https?://)www.example.com/(.*)$")
    assert_equal "\"https://example.com/\\$2\"",
      Kamal::Utils.escape_shell_value("https://example.com/$2")
  end
end
