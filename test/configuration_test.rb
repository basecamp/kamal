require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    ENV["RAILS_MASTER_KEY"] = "456"
    ENV["VERSION"] = "missing"

    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      builder: { "arch" => "amd64" },
      env: { "REDIS_URL" => "redis://x/y" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      volumes: [ "/local/path:/container/path" ]
    }

    @config = Kamal::Configuration.new(@deploy)

    @deploy_with_roles = @deploy.dup.merge({
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "workers" => { "hosts" => [ "1.1.1.1", "1.1.1.3" ] } } })

    @config_with_roles = Kamal::Configuration.new(@deploy_with_roles)
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
    ENV.delete("VERSION")
  end

  %i[ service image registry ].each do |key|
    test "#{key} config required" do
      assert_raise(Kamal::ConfigurationError) do
        Kamal::Configuration.new @deploy.tap { _1.delete key }
      end
    end
  end

  %w[ username password ].each do |key|
    test "registry #{key} required" do
      assert_raise(Kamal::ConfigurationError) do
        Kamal::Configuration.new @deploy.tap { _1[:registry].delete key }
      end
    end
  end

  test "service name valid" do
    assert_nothing_raised do
      Kamal::Configuration.new(@deploy.tap { _1[:service] = "hey-app1_primary" })
      Kamal::Configuration.new(@deploy.tap { _1[:service] = "MyApp" })
    end
  end

  test "service name invalid" do
    assert_raise(Kamal::ConfigurationError) do
      Kamal::Configuration.new @deploy.tap { _1[:service] = "app.com" }
    end
  end

  test "roles" do
    assert_equal %w[ web ], @config.roles.collect(&:name)
    assert_equal %w[ web workers ], @config_with_roles.roles.collect(&:name)
  end

  test "role" do
    assert @config.role(:web).name.web?
    assert_equal "workers", @config_with_roles.role(:workers).name
    assert_nil @config.role(:missing)
  end

  test "all hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @config.all_hosts
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3" ], @config_with_roles.all_hosts
  end

  test "primary host" do
    assert_equal "1.1.1.1", @config.primary_host
    assert_equal "1.1.1.1", @config_with_roles.primary_host
  end

  test "proxy hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @config_with_roles.proxy_hosts

    @deploy_with_roles[:servers]["workers"]["proxy"] = true
    config = Kamal::Configuration.new(@deploy_with_roles)

    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3" ], config.proxy_hosts
  end

  test "filtered proxy hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @config_with_roles.proxy_hosts

    @deploy_with_roles[:servers]["workers"]["proxy"] = true
    config = Kamal::Configuration.new(@deploy_with_roles)

    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3" ], config.proxy_hosts
  end

  test "version no git repo" do
    ENV.delete("VERSION")

    Kamal::Git.expects(:used?).returns(nil)
    error = assert_raises(RuntimeError) { @config.version }
    assert_match /no git repository found/, error.message
  end

  test "version from git committed" do
    ENV.delete("VERSION")

    Kamal::Git.expects(:revision).returns("git-version")
    Kamal::Git.expects(:uncommitted_changes).returns("")
    assert_equal "git-version", @config.version
  end

  test "version from git uncommitted" do
    ENV.delete("VERSION")

    Kamal::Git.expects(:revision).returns("git-version")
    Kamal::Git.expects(:uncommitted_changes).returns("M   file\n")
    assert_equal "git-version", @config.version
  end

  test "version from uncommitted context" do
    ENV.delete("VERSION")

    config = Kamal::Configuration.new(@deploy.tap { |c| c[:builder]["context"] = "." })

    Kamal::Git.expects(:revision).returns("git-version")
    Kamal::Git.expects(:uncommitted_changes).returns("M   file\n")
    assert_match /^git-version_uncommitted_[0-9a-f]{16}$/, config.version
  end

  test "version from env" do
    ENV["VERSION"] = "env-version"
    assert_equal "env-version", @config.version
  end

  test "version from arg" do
    @config.version = "arg-version"
    assert_equal "arg-version", @config.version
  end

  test "repository" do
    assert_equal "dhh/app", @config.repository

    config = Kamal::Configuration.new(@deploy.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app", config.repository
  end

  test "absolute image" do
    assert_equal "dhh/app:missing", @config.absolute_image

    config = Kamal::Configuration.new(@deploy.tap { |c| c[:registry].merge!({ "server" => "ghcr.io" }) })
    assert_equal "ghcr.io/dhh/app:missing", config.absolute_image
  end

  test "service with version" do
    assert_equal "app-missing", @config.service_with_version
  end

  test "hosts required for all roles" do
    # Empty server list for implied web role
    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new @deploy.merge(servers: [])
    end

    # Empty server list
    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => [] })
    end

    # Missing hosts key
    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => {} })
    end

    # Empty hosts list
    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => { "hosts" => [] } })
    end

    # Nil hosts
    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => { "hosts" => nil } })
    end

    # One role with hosts, one without
    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => %w[ web ], "workers" => { "hosts" => %w[ ] } })
    end
  end

  test "allow_empty_roles" do
    assert_silent do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => %w[ web ], "workers" => { "hosts" => %w[ ] } }, allow_empty_roles: true)
    end

    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => %w[], "workers" => { "hosts" => %w[] } }, allow_empty_roles: true)
    end
  end

  test "volume_args" do
    assert_equal [ "--volume", "/local/path:/container/path" ], @config.volume_args
  end

  test "logging args default" do
    assert_equal [ "--log-opt", "max-size=\"10m\"" ], @config.logging_args
  end

  test "logging args with configured options" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(logging: { "options" => { "max-size" => "100m", "max-file" => 5 } }) })
    assert_equal [ "--log-opt", "max-size=\"100m\"", "--log-opt", "max-file=\"5\"" ], config.logging_args
  end

  test "logging args with configured driver and options" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(logging: { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => 5 } }) })
    assert_equal [ "--log-driver", "\"local\"", "--log-opt", "max-size=\"100m\"", "--log-opt", "max-file=\"5\"" ], config.logging_args
  end

  test "erb evaluation of yml config" do
    config = Kamal::Configuration.create_from config_file: Pathname.new(File.expand_path("fixtures/deploy.erb.yml", __dir__))
    assert_equal "my-user", config.registry.username
  end

  test "destination is loaded into env" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    config = Kamal::Configuration.create_from config_file: dest_config_file, destination: "world"
    assert_equal ENV["KAMAL_DESTINATION"], "world"
  end

  test "destination yml config merge" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    config = Kamal::Configuration.create_from config_file: dest_config_file, destination: "world"
    assert_equal "1.1.1.1", config.all_hosts.first

    config = Kamal::Configuration.create_from config_file: dest_config_file, destination: "mars"
    assert_equal "1.1.1.3", config.all_hosts.first
  end

  test "destination yml config file missing" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    assert_raises(RuntimeError) do
      config = Kamal::Configuration.create_from config_file: dest_config_file, destination: "missing"
    end
  end

  test "destination required" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_required_dest.yml", __dir__))

    assert_raises(Kamal::ConfigurationError) do
      config = Kamal::Configuration.create_from config_file: dest_config_file
    end

    assert_nothing_raised do
      config = Kamal::Configuration.create_from config_file: dest_config_file, destination: "world"
    end
  end

  test "to_h" do
    expected_config = \
      { roles: [ "web" ],
        hosts: [ "1.1.1.1", "1.1.1.2" ],
        primary_host: "1.1.1.1",
        version: "missing",
        repository: "dhh/app",
        absolute_image: "dhh/app:missing",
        service_with_version: "app-missing",
        ssh_options: { user: "root", port: 22, log_level: :fatal, keepalive: true, keepalive_interval: 30 },
        sshkit: {},
        volume_args: [ "--volume", "/local/path:/container/path" ],
        builder: { "arch" => "amd64" },
        logging: [ "--log-opt", "max-size=\"10m\"" ] }

    assert_equal expected_config, @config.to_h
  end

  test "min version is lower" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(minimum_version: "0.0.1") })
    assert_equal "0.0.1", config.minimum_version
  end

  test "min version is equal" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(minimum_version: Kamal::VERSION) })
    assert_equal Kamal::VERSION, config.minimum_version
  end

  test "min version is higher" do
    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new(@deploy.tap { |c| c.merge!(minimum_version: "10000.0.0") })
    end
  end

  test "run directory" do
    config = Kamal::Configuration.new(@deploy)
    assert_equal ".kamal", config.run_directory
  end

  test "asset path" do
    assert_nil @config.asset_path
    assert_equal "foo", Kamal::Configuration.new(@deploy.merge!(asset_path: "foo")).asset_path
  end

  test "primary role" do
    assert_equal "web", @config.primary_role.name

    config = Kamal::Configuration.new(@deploy_with_roles.deep_merge({
      servers: { "alternate_web" => { "hosts" => [ "1.1.1.4", "1.1.1.5" ] } },
      primary_role: "alternate_web" }))


    assert_equal "alternate_web", config.primary_role.name
    assert_equal "1.1.1.4", config.primary_host
    assert config.role(:alternate_web).primary?
    assert config.role(:alternate_web).running_proxy?
  end

  test "primary role missing" do
    error = assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new(@deploy.merge(primary_role: "bar"))
    end
    assert_match /bar isn't defined/, error.message
  end

  test "retain_containers" do
    assert_equal 5, @config.retain_containers
    config = Kamal::Configuration.new(@deploy_with_roles.merge(retain_containers: 2))
    assert_equal 2, config.retain_containers

    assert_raises(Kamal::ConfigurationError) { Kamal::Configuration.new(@deploy_with_roles.merge(retain_containers: 0)) }
  end

  test "extensions" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_with_extensions.yml", __dir__))

    config = Kamal::Configuration.create_from config_file: dest_config_file
    assert_equal config.role(:web_tokyo).running_proxy?, true
    assert_equal config.role(:web_chicago).running_proxy?, true
  end

  test "traefik hooks raise error" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        FileUtils.mkdir_p ".kamal/hooks"
        FileUtils.touch ".kamal/hooks/post-traefik-reboot"
        FileUtils.touch ".kamal/hooks/pre-traefik-reboot"
        exception = assert_raises(Kamal::ConfigurationError) do
          Kamal::Configuration.new(@deploy)
        end
        assert_equal "Found pre-traefik-reboot, post-traefik-reboot, these should be renamed to (pre|post)-proxy-reboot", exception.message
      end
    end
  end

  test "proxy ssl roles with no host" do
    @deploy_with_roles[:servers]["workers"]["proxy"] = { "ssl" => true }

    exception = assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new(@deploy_with_roles)
    end

    assert_equal "servers/workers/proxy: Must set a host to enable automatic SSL", exception.message
  end

  test "proxy ssl roles with multiple servers" do
    @deploy_with_roles[:servers]["workers"]["proxy"] = { "ssl" => true, "host" => "foo.example.com" }

    exception = assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new(@deploy_with_roles)
    end

    assert_equal "SSL is only supported on a single server, found 2 servers for role workers", exception.message
  end

  test "two proxy ssl roles with same host" do
    @deploy_with_roles[:servers]["web"] = { "hosts" => [ "1.1.1.1" ], "proxy" => { "ssl" => true, "host" => "foo.example.com" } }
    @deploy_with_roles[:servers]["workers"] = { "hosts" => [ "1.1.1.1" ], "proxy" => { "ssl" => true, "host" => "foo.example.com" } }

    exception = assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new(@deploy_with_roles)
    end

    assert_equal "Different roles can't share the same host for SSL: foo.example.com", exception.message
  end

  test "two proxy ssl roles with same host in a hosts array" do
    @deploy_with_roles[:servers]["web"] = { "hosts" => [ "1.1.1.1" ], "proxy" => { "ssl" => true, "hosts" => [ "foo.example.com", "bar.example.com" ] } }
    @deploy_with_roles[:servers]["workers"] = { "hosts" => [ "1.1.1.1" ], "proxy" => { "ssl" => true, "hosts" => [ "www.example.com", "foo.example.com" ] } }

    exception = assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new(@deploy_with_roles)
    end

    assert_equal "Different roles can't share the same host for SSL: foo.example.com", exception.message
  end
end
