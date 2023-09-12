require "test_helper"

class UtilsTest < ActiveSupport::TestCase
  test "argumentize" do
    assert_equal [ "--label", "foo=\"\\`bar\\`\"", "--label", "baz=\"qux\"", "--label", :quux ], \
      Kamal::Utils.argumentize("--label", { foo: "`bar`", baz: "qux", quux: nil })
  end

  test "argumentize with redacted" do
    assert_kind_of SSHKit::Redaction, \
      Kamal::Utils.argumentize("--label", { foo: "bar" }, sensitive: true).last
  end

  test "env file simple" do
    env = {
      "foo" => "bar",
      "baz" => "haz"
    }

    assert_equal "foo=bar\nbaz=haz\n", \
      Kamal::Utils.env_file_with_secrets(env)
  end

  test "env file clear" do
    env = {
      "clear" => {
        "foo" => "bar",
        "baz" => "haz"
      }
    }

    assert_equal "foo=bar\nbaz=haz\n", \
      Kamal::Utils.env_file_with_secrets(env)
  end

  test "env file empty" do
    assert_equal "\n", Kamal::Utils.env_file_with_secrets({})
  end

  test "env file secret" do
    ENV["PASSWORD"] = "hello"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\n", \
      Kamal::Utils.env_file_with_secrets(env)
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file secret escaped newline" do
    ENV["PASSWORD"] = "hello\\nthere"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\\\\nthere\n", \
      Kamal::Utils.env_file_with_secrets(env)
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file secret newline" do
    ENV["PASSWORD"] = "hello\nthere"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\\nthere\n", \
      Kamal::Utils.env_file_with_secrets(env)
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file missing secret" do
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_raises(KeyError) { Kamal::Utils.env_file_with_secrets(env) }

  ensure
    ENV.delete "PASSWORD"
  end

  test "env file secret and clear" do
    ENV["PASSWORD"] = "hello"
    env = {
      "secret" => [ "PASSWORD" ],
      "clear" => {
        "foo" => "bar",
        "baz" => "haz"
      }
    }

    assert_equal "PASSWORD=hello\nfoo=bar\nbaz=haz\n", \
      Kamal::Utils.env_file_with_secrets(env)
  ensure
    ENV.delete "PASSWORD"
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

  test "uncommitted changes exist" do
    Kamal::Utils.expects(:`).with("git status --porcelain").returns("M   file\n")
    assert_equal "M   file", Kamal::Utils.uncommitted_changes
  end

  test "uncommitted changes do not exist" do
    Kamal::Utils.expects(:`).with("git status --porcelain").returns("")
    assert_equal "", Kamal::Utils.uncommitted_changes
  end
end
