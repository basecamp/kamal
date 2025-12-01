require "test_helper"

class SecretsInlineCommandSubstitution < SecretAdapterTestCase
  test "inlines kamal secrets commands" do
    Kamal::Cli::Main.expects(:start).with { |command| command == [ "secrets", "fetch", "...", "--inline" ] }.returns("results")
    substituted = Kamal::Secrets::Dotenv::InlineCommandSubstitution.call("FOO=$(kamal secrets fetch ...)", nil, overwrite: false)
    assert_equal "FOO=results", substituted
  end

  test "executes other commands" do
    Kamal::Secrets::Dotenv::InlineCommandSubstitution.stubs(:`).with("blah").returns("results")
    substituted = Kamal::Secrets::Dotenv::InlineCommandSubstitution.call("FOO=$(blah)", nil, overwrite: false)
    assert_equal "FOO=results", substituted
  end

  test "handles escaped parentheses in command arguments" do
    command_with_escaped_parens = 'kamal secrets extract KEY1 \{\"KEY1\":\"pass\)word\"\}'
    Kamal::Cli::Main.expects(:start).with { |cmd|
      cmd.first(3) == [ "secrets", "extract", "KEY1" ] &&
      cmd[3] == '{"KEY1":"pass)word"}'  # shellsplit should unescape
    }.returns("pass)word")

    substituted = Kamal::Secrets::Dotenv::InlineCommandSubstitution.call(
      "KEY1=$(#{command_with_escaped_parens})", nil, overwrite: false
    )
    assert_equal "KEY1=pass)word", substituted
  end
end
