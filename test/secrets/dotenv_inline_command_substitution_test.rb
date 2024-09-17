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
end
