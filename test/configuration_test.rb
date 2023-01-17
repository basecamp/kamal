require "test_helper"
require "mrsk/configuration"

ENV["VERSION"] = "123"
ENV["RAILS_MASTER_KEY"] = "456"

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      env: { "REDIS_URL" => "redis://x/y" },
      servers: [ "1.1.1.1", "1.1.1.2" ]
    }

    @config = Mrsk::Configuration.new(@deploy)

    @deploy_with_roles = @deploy.dup.merge({
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "workers" => { "hosts" => [ "1.1.1.3", "1.1.1.4" ] } } })

    @config_with_roles = Mrsk::Configuration.new(@deploy_with_roles)
  end

  test "ensure valid keys" do
    assert_raise(ArgumentError) do
      Mrsk::Configuration.new(@deploy.tap { _1.delete(:service) })
      Mrsk::Configuration.new(@deploy.tap { _1.delete(:image) })
      Mrsk::Configuration.new(@deploy.tap { _1.delete(:registry) })

      Mrsk::Configuration.new(@deploy.tap { _1[:registry].delete("username") })
      Mrsk::Configuration.new(@deploy.tap { _1[:registry].delete("password") })
    end
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

  test "hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2"], @config.hosts
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @config_with_roles.hosts
  end

  test "hosts from ENV" do
    ENV["HOSTS"] = "1.1.1.5,1.1.1.6"
    assert_equal [ "1.1.1.5", "1.1.1.6"], @config.hosts
  ensure
    ENV["HOSTS"] = nil
  end

  test "hosts from ENV roles" do
    ENV["ROLES"] = "web,workers"
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4" ], @config_with_roles.hosts

    ENV["ROLES"] = "workers"
    assert_equal [ "1.1.1.3", "1.1.1.4" ], @config_with_roles.hosts
  ensure
    ENV["ROLES"] = nil
  end

  test "primary host" do
    assert_equal "1.1.1.1", @config.primary_host
    assert_equal "1.1.1.1", @config_with_roles.primary_host
  end


  test "version" do
    assert_equal "123", @config.version
  end

  test "repository" do
    assert_equal "dhh/app", @config.repository

    config = Mrsk::Configuration.new(@deploy.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app", config.repository
  end

  test "absolute image" do
    assert_equal "dhh/app:123", @config.absolute_image

    config = Mrsk::Configuration.new(@deploy.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app:123", config.absolute_image
  end

  test "service with version" do
    assert_equal "app-123", @config.service_with_version
  end


  test "env args" do
    assert_equal [ "-e", "REDIS_URL=redis://x/y" ], @config.env_args
  end

  test "ssh options" do
    assert_equal "root", @config.ssh_options[:user]

    config = Mrsk::Configuration.new(@deploy.tap { |c| c[:ssh_user] = "app" })
    assert_equal "app", @config.ssh_options[:user]
  end

  test "master key" do
    assert_equal "456", @config.master_key
  end


  test "erb evaluation of yml config" do
    config = Mrsk::Configuration.create_from Pathname.new(File.expand_path("fixtures/deploy.erb.yml", __dir__))
    assert_equal "my-user", config.registry["username"]
  end

  test "destination yml config merge" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    config = Mrsk::Configuration.create_from dest_config_file, destination: "world"
    assert_equal "1.1.1.1", config.hosts.first

    config = Mrsk::Configuration.create_from dest_config_file, destination: "mars"
    assert_equal "1.1.1.3", config.hosts.first
  end

  test "destination yml config file missing" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    assert_raises(RuntimeError) do
      config = Mrsk::Configuration.create_from dest_config_file, destination: "missing"
    end
  end
end
