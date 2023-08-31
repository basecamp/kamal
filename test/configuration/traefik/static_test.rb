require "test_helper"

class ConfigurationTraefikStaticTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      env: { "REDIS_URL" => "redis://x/y" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      volumes: ["/local/path:/container/path"],
      traefik: {}
    }

    @config = Kamal::Configuration.new(@deploy)
  end

  test "env_file" do
    ENV["EXAMPLE_API_KEY"] = "456"
    @config.traefik["env"] = { "secret" => %w[EXAMPLE_API_KEY] }
    traefik_static = Kamal::Configuration::Traefik::Static.new(config: @config)

    assert_equal "EXAMPLE_API_KEY=456\n", traefik_static.env_file
  ensure
    ENV.delete "EXAMPLE_API_KEY"
  end
end
