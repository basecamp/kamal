require "test_helper"

class ConfigurationEnvTest < ActiveSupport::TestCase
  require "test_helper"

  test "simple" do
    assert_config \
      config: { "foo" => "bar", "baz" => "haz" },
      results: { "foo" => "bar", "baz" => "haz" }
  end

  test "clear" do
    assert_config \
      config: { "clear" => { "foo" => "bar", "baz" => "haz" } },
      results: { "foo" => "bar", "baz" => "haz" }
  end

  test "secret" do
    with_test_secrets("secrets" => "PASSWORD=hello") do
      assert_config \
        config: { "secret" => [ "PASSWORD" ] },
        results: { "PASSWORD" => "hello" }
    end
  end

  test "missing secret" do
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_raises(Kamal::ConfigurationError) { Kamal::Configuration::Env.new(config: { "secret" => [ "PASSWORD" ] }, secrets: Kamal::Secrets.new).args }
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
        results: { "foo" => "bar", "baz" => "haz", "PASSWORD" => "hello" }
    end
  end

  private
    def assert_config(config:, results:)
      env = Kamal::Configuration::Env.new config: config, secrets: Kamal::Secrets.new
      expected_args = results.to_a.flat_map { |key, value| [ "--env", "#{key}=\"#{value}\"" ] }
      assert_equal expected_args, env.args.map(&:to_s) #  to_s removes the redactions
    end
end
