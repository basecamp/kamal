require "test_helper"

class ConfigurationEnvTest < ActiveSupport::TestCase
  require "test_helper"

  test "simple" do
    assert_config \
      config: { "foo" => "bar", "baz" => "haz" },
      clear: { "foo" => "bar", "baz" => "haz" }
  end

  test "clear" do
    assert_config \
      config: { "clear" => { "foo" => "bar", "baz" => "haz" } },
      clear: { "foo" => "bar", "baz" => "haz" }
  end

  test "secret" do
    with_test_secrets("secrets" => "PASSWORD=hello") do
      assert_config \
        config: { "secret" => [ "PASSWORD" ] },
        secrets: { "PASSWORD" => "hello" }
    end
  end

  test "missing secret" do
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_raises(Kamal::ConfigurationError) { Kamal::Configuration::Env.new(config: { "secret" => [ "PASSWORD" ] }, secrets: Kamal::Secrets.new).secrets_io }
  end

  test "secret and clear" do
    with_test_secrets("secrets" => "PASSWORD=hello") do
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
    end
  end

  private
    def assert_config(config:, clear: {}, secrets: {})
      env = Kamal::Configuration::Env.new config: config, secrets: Kamal::Secrets.new
      expected_clear_args = clear.to_a.flat_map { |key, value| [ "--env", "#{key}=\"#{value}\"" ] }
      assert_equal expected_clear_args, env.clear_args.map(&:to_s) #  to_s removes the redactions
      expected_secrets = secrets.to_a.flat_map { |key, value| "#{key}=#{value}" }.join("\n") + "\n"
      assert_equal expected_secrets, env.secrets_io.string
    end
end
