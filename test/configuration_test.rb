require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  setup do
    ENV["RAILS_MASTER_KEY"] = "456"
    ENV["VERSION"] = "missing"

    @deploy = {
      service: "app", image: "dhh/app",
      registry: { "username" => "dhh", "password" => "secret" },
      env: { "REDIS_URL" => "redis://x/y" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      volumes: ["/local/path:/container/path"]
    }

    @config = Mrsk::Configuration.new(@deploy)

    @deploy_with_roles = @deploy.dup.merge({
      servers: { "web" => [ "1.1.1.1", "1.1.1.2" ], "workers" => { "hosts" => [ "1.1.1.1", "1.1.1.3" ] } } })

    @config_with_roles = Mrsk::Configuration.new(@deploy_with_roles)
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
    ENV.delete("VERSION")
  end

  %i[ service image registry ].each do |key|
    test "#{key} config required" do
      assert_raise(ArgumentError) do
        Mrsk::Configuration.new @deploy.tap { _1.delete key }
      end
    end
  end

  %w[ username password ].each do |key|
    test "registry #{key} required" do
      assert_raise(ArgumentError) do
        Mrsk::Configuration.new @deploy.tap { _1[:registry].delete key }
      end
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
    assert_equal [ "1.1.1.1", "1.1.1.2"], @config.all_hosts
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3" ], @config_with_roles.all_hosts
  end

  test "primary web host" do
    assert_equal "1.1.1.1", @config.primary_web_host
    assert_equal "1.1.1.1", @config_with_roles.primary_web_host
  end

  test "traefik hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @config_with_roles.traefik_hosts

    @deploy_with_roles[:servers]["workers"]["traefik"] = true
    config = Mrsk::Configuration.new(@deploy_with_roles)

    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3" ], config.traefik_hosts
  end

  test "version no git repo" do
    ENV.delete("VERSION")

    @config.expects(:system).with("git rev-parse").returns(nil)
    error = assert_raises(RuntimeError) { @config.version}
    assert_match /no git repository found/, error.message
  end

  test "version from git committed" do
    ENV.delete("VERSION")

    @config.expects(:`).with("git rev-parse HEAD").returns("git-version")
    @config.expects(:`).with("git status --porcelain").returns("")
    assert_equal "git-version", @config.version
  end

  test "version from git uncommitted" do
    ENV.delete("VERSION")

    @config.expects(:`).with("git rev-parse HEAD").returns("git-version")
    @config.expects(:`).with("git status --porcelain").returns("M   file\n")
    assert_match /^git-version_uncommitted_[0-9a-f]{16}$/, @config.version
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

    assert_equal [ "-e", "PASSWORD=\"secret123\"", "-e", "PORT=\"3000\"" ], Mrsk::Utils.unredacted(config.env_args)
    assert_equal [ "-e", "PASSWORD=[REDACTED]", "-e", "PORT=\"3000\"" ], Mrsk::Utils.redacted(config.env_args)
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

    assert_equal [ "-e", "PASSWORD=\"secret123\"" ], Mrsk::Utils.unredacted(config.env_args)
    assert_equal [ "-e", "PASSWORD=[REDACTED]" ], Mrsk::Utils.redacted(config.env_args)
  ensure
    ENV["PASSWORD"] = nil
  end

  test "env args with missing secret" do
    assert_raises(KeyError) do
      config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!({
        env: { "secret" => [ "PASSWORD" ] }
      }) }).ensure_env_available
    end
  end

  test "valid config" do
    assert @config.valid?
    assert @config_with_roles.valid?
  end

  test "hosts required for all roles" do
    # Empty server list for implied web role
    assert_raises(ArgumentError) do
      Mrsk::Configuration.new @deploy.merge(servers: [])
    end

    # Empty server list
    assert_raises(ArgumentError) do
      Mrsk::Configuration.new @deploy.merge(servers: { "web" => [] })
    end

    # Missing hosts key
    assert_raises(ArgumentError) do
      Mrsk::Configuration.new @deploy.merge(servers: { "web" => {} })
    end

    # Empty hosts list
    assert_raises(ArgumentError) do
      Mrsk::Configuration.new @deploy.merge(servers: { "web" => { "hosts" => [] } })
    end

    # Nil hosts
    assert_raises(ArgumentError) do
      Mrsk::Configuration.new @deploy.merge(servers: { "web" => { "hosts" => nil } })
    end

    # One role with hosts, one without
    assert_raises(ArgumentError) do
      Mrsk::Configuration.new @deploy.merge(servers: { "web" => %w[ web ], "workers" => { "hosts" => %w[ ] } })
    end
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

  test "logging args default" do
    assert_equal ["--log-opt", "max-size=\"10m\""], @config.logging_args
  end

  test "logging args with configured options" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(logging: { "options" => { "max-size" => "100m", "max-file" => 5 } }) })
    assert_equal ["--log-opt", "max-size=\"100m\"", "--log-opt", "max-file=\"5\""], @config.logging_args
  end

  test "logging args with configured driver and options" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(logging: { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => 5 } }) })
    assert_equal ["--log-driver", "\"local\"", "--log-opt", "max-size=\"100m\"", "--log-opt", "max-file=\"5\""], @config.logging_args
  end

  test "erb evaluation of yml config" do
    config = Mrsk::Configuration.create_from config_file: Pathname.new(File.expand_path("fixtures/deploy.yml.erb", __dir__))
    assert_equal "my-user", config.registry["username"]
  end

  test "erb evaluation of yml config with destinations" do
    config_file = Pathname.new(File.expand_path("fixtures/deploy.yml.erb", __dir__))

    config = Mrsk::Configuration.create_from config_file: config_file, destination: 'staging'
    assert_equal "my-user", config.registry["username"]
    assert_equal "my-password-override", config.registry["password"]
  end

  test "destination yml config merge" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    config = Mrsk::Configuration.create_from config_file: dest_config_file, destination: "world"
    assert_equal "1.1.1.1", config.all_hosts.first

    config = Mrsk::Configuration.create_from config_file: dest_config_file, destination: "mars"
    assert_equal "1.1.1.3", config.all_hosts.first
  end

  test "destination yml config file missing" do
    dest_config_file = Pathname.new(File.expand_path("fixtures/deploy_for_dest.yml", __dir__))

    assert_raises(RuntimeError) do
      config = Mrsk::Configuration.create_from config_file: dest_config_file, destination: "missing"
    end
  end

  test "to_h" do
    assert_equal({ :roles=>["web"], :hosts=>["1.1.1.1", "1.1.1.2"], :primary_host=>"1.1.1.1", :version=>"missing", :repository=>"dhh/app", :absolute_image=>"dhh/app:missing", :service_with_version=>"app-missing", :env_args=>["-e", "REDIS_URL=\"redis://x/y\""], :ssh_options=>{:user=>"root", :auth_methods=>["publickey"]}, :volume_args=>["--volume", "/local/path:/container/path"], :builder=>{}, :logging=>["--log-opt", "max-size=\"10m\""], :healthcheck=>{"path"=>"/up", "port"=>3000, "max_attempts" => 7 }}, @config.to_h)
  end

  test "min version is lower" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(minimum_version: "0.0.1") })
    assert_equal "0.0.1", config.minimum_version
  end

  test "min version is equal" do
    config = Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(minimum_version: Mrsk::VERSION) })
    assert_equal Mrsk::VERSION, config.minimum_version
  end

  test "min version is higher" do
    assert_raises(ArgumentError) do
      Mrsk::Configuration.new(@deploy.tap { |c| c.merge!(minimum_version: "10000.0.0") })
    end
  end
end
