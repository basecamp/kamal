require "test_helper"

class ConfigurationEnvTest < ActiveSupport::TestCase
  require "test_helper"

  test "simple" do
    assert_config \
      config: { "foo" => "bar", "baz" => "haz" },
      clear: { "foo" => "bar", "baz" => "haz" },
      secrets: {}
  end

  test "clear" do
    assert_config \
      config: { "clear" => { "foo" => "bar", "baz" => "haz" } },
      clear: { "foo" => "bar", "baz" => "haz" },
      secrets: {}
  end

  test "secret" do
    ENV["PASSWORD"] = "hello"
    env = Kamal::Configuration::Env.new config: { "secret" => [ "PASSWORD" ] }

    assert_config \
      config: { "secret" => [ "PASSWORD" ] },
      clear: {},
      secrets: { "PASSWORD" => "hello" }
  ensure
    ENV.delete "PASSWORD"
  end

  test "missing secret" do
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_raises(KeyError) { Kamal::Configuration::Env.new(config: { "secret" => [ "PASSWORD" ] }).secrets }
  end

  test "secret and clear" do
    ENV["PASSWORD"] = "hello"
    config = {
      "secret" => [ "PASSWORD" ],
      "clear" => {
        "foo" => "bar",
        "baz" => "haz"
      }
    }

    assert_config \
      config: config,
      clear: { "foo" => "bar", "baz" => "haz" },
      secrets: { "PASSWORD" => "hello" }
  ensure
    ENV.delete "PASSWORD"
  end

  test "stringIO conversion" do
    env = {
      "foo" => "bar",
      "baz" => "haz"
    }

    assert_equal "foo=bar\nbaz=haz\n", \
      StringIO.new(Kamal::EnvFile.new(env)).read
  end

  private
    def assert_config(config:, clear:, secrets:)
      env = Kamal::Configuration::Env.new config: config, secrets_file: "secrets.env"
      assert_equal clear, env.clear
      assert_equal secrets, env.secrets
    end
end
