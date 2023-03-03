require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    ENV["RAILS_MASTER_KEY"] = "456"

    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      env: { "REDIS_URL" => "redis://x/y" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      volumes: ["/local/path:/container/path"]
    }

    @config = Mrsk::Configuration.new(@deploy)

    @deploy_with_roles = @deploy.dup.merge({
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "workers" => { "hosts" => [ "1.1.1.3", "1.1.1.4" ] } } })

    @config_with_roles = Mrsk::Configuration.new(@deploy_with_roles)
  end

  teardown do
    ENV["RAILS_MASTER_KEY"] = nil
  end

  test "roles" do
    assert_equal %w[ web ], @config.roles.collect(&:name)
    assert_equal %w[ web workers ], @config_with_roles.roles.collect(&:name)
  end

  test "role" do
    assert_equal "web", @config.role(:web).name
    assert_equal "workers", @config_with_roles.role(:workers).name
    assert_nil @config.role(:missing)
  end

  test "all hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2"], @config.all_hosts
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @config_with_roles.all_hosts
  end

  test "primary web host" do
    assert_equal "1.1.1.1", @config.primary_web_host
    assert_equal "1.1.1.1", @config_with_roles.primary_web_host
  end

  test "traefik hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @config_with_roles.traefik_hosts

    @deploy_with_roles[:servers]["workers"]["traefik"] = true
    config = Mrsk::Configuration.new(@deploy_with_roles)

    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], config.traefik_hosts
  end

  test "version" do
    assert_equal "missing", @config.version
    assert_equal "123", Mrsk::Configuration.new(@deploy, version: "123").version
  end

  test "repository" do
    assert_equal "dhh/app", @config.repository

    config = Mrsk::Configuration.new(@deploy.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app", config.repository
  end

  test "absolute image" do
    assert_equal "dhh/app:missing", @config.absolute_image

    config = Mrsk::Configuration.new(@deploy.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app:missing", config.absolute_image
  end

  test "service with version" do
    assert_equal "app-missing", @config.service_with_version
  end

  test "env args" do
    assert_equal [ "-e", "REDIS_URL=\"redis://x/y\"" ], @config.env_args
  end

  test "env args with clear and secrets" do
    ENV["PASSWORD"] = "secret123"
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!({
      env: { "clear" => { "PORT" => "3000" }, "secret" => [ "PASSWORD" ] }
    }) })

    assert_equal [ "-e", "PASSWORD=\"secret123\"", "-e", "PORT=\"3000\"" ], config.env_args
    assert config.env_args[1].is_a?(SSHKit::Redaction)
  ensure
    ENV["PASSWORD"] = nil
  end

  test "env args with only clear" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!({
      env: { "clear" => { "PORT" => "3000" } }
    }) })

    assert_equal [ "-e", "PORT=\"3000\"" ], config.env_args
  end

  test "env args with only secrets" do
    ENV["PASSWORD"] = "secret123"
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!({
      env: { "secret" => [ "PASSWORD" ] }
    }) })

    assert_equal [ "-e", "PASSWORD=\"secret123\"" ], config.env_args
    assert config.env_args[1].is_a?(SSHKit::Redaction)
  ensure
    ENV["PASSWORD"] = nil
  end

  test "env args with missing secret" do
    assert_raises(KeyError) do
      config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!({
        env: { "secret" => [ "PASSWORD" ] }
      }) })
    end
  end

  test "configuration schema is valid" do
    cwd = File.dirname(File.expand_path(__FILE__))
    metaschema_file_path = File.join(cwd, "/fixtures/files/draft-04-schema.json")
    metaschema = JSON.parse(IO.read(metaschema_file_path))

    schema_file_path = File.join(cwd, "../lib/mrsk/configuration/schema.yaml")
    schema = YAML.load(IO.read(schema_file_path))

    assert JSON::Validator.validate(metaschema, schema)
  end

  test "configuration schema raises errors on fail" do
    assert_raise(Mrsk::Configuration::Error) { Mrsk::Configuration.new(@deploy.tap { _1.delete(:service) }) }
    assert_raise(Mrsk::Configuration::Error) { Mrsk::Configuration.new(@deploy.tap { _1[:registry].delete("username") }) }
  end

  test "ssh options" do
    assert_equal "root", @config.ssh_options[:user]

    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "user" => "app" }) })
    assert_equal "app", @config.ssh_options[:user]
  end

  test "ssh options with proxy host" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "proxy" => "1.2.3.4" }) })
    assert_equal "root@1.2.3.4", @config.ssh_options[:proxy].jump_proxies
  end

  test "ssh options with proxy host and user" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(ssh: { "proxy" => "app@1.2.3.4" }) })
    assert_equal "app@1.2.3.4", @config.ssh_options[:proxy].jump_proxies
  end

  test "volume_args" do
    assert_equal ["--volume", "/local/path:/container/path"], @config.volume_args
  end

  test "erb evaluation of yml config" do
    config = Mrsk::Configuration.create_from Pathname.new(File.expand_path("fixtures/deploy.erb.yml", __dir__))
    assert_equal "my-user", config.registry["username"]
  end

  test "destination yml config merge" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    config = Mrsk::Configuration.create_from dest_config_file, destination: "world"
    assert_equal "1.1.1.1", config.all_hosts.first

    config = Mrsk::Configuration.create_from dest_config_file, destination: "mars"
    assert_equal "1.1.1.3", config.all_hosts.first
  end

  test "destination yml config file missing" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    assert_raises(RuntimeError) do
      config = Mrsk::Configuration.create_from dest_config_file, destination: "missing"
    end
  end

  test "to_h" do
    assert_equal({ :roles=>["web"], :hosts=>["1.1.1.1", "1.1.1.2"], :primary_host=>"1.1.1.1", :version=>"missing", :repository=>"dhh/app", :absolute_image=>"dhh/app:missing", :service_with_version=>"app-missing", :env_args=>["-e", "REDIS_URL=\"redis://x/y\""], :ssh_options=>{:user=>"root", :auth_methods=>["publickey"]}, :volume_args=>["--volume", "/local/path:/container/path"], :healthcheck=>{"path"=>"/up", "port"=>3000 }}, @config.to_h)
  end
end
