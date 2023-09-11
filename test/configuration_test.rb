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
      assert_raise(ArgumentError) do
        Kamal::Configuration.new @deploy.tap { _1.delete key }
      end
    end
  end

  %w[ username password ].each do |key|
    test "registry #{key} required" do
      assert_raise(ArgumentError) do
        Kamal::Configuration.new @deploy.tap { _1[:registry].delete key }
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
    config = Kamal::Configuration.new(@deploy_with_roles)

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
    Kamal::Utils.expects(:uncommitted_changes).returns("")
    assert_equal "git-version", @config.version
  end

  test "version from git uncommitted" do
    ENV.delete("VERSION")

    @config.expects(:`).with("git rev-parse HEAD").returns("git-version")
    Kamal::Utils.expects(:uncommitted_changes).returns("M   file\n")
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

  test "env with missing secret" do
    assert_raises(KeyError) do
      config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!({
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
      Kamal::Configuration.new @deploy.merge(servers: [])
    end

    # Empty server list
    assert_raises(ArgumentError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => [] })
    end

    # Missing hosts key
    assert_raises(ArgumentError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => {} })
    end

    # Empty hosts list
    assert_raises(ArgumentError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => { "hosts" => [] } })
    end

    # Nil hosts
    assert_raises(ArgumentError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => { "hosts" => nil } })
    end

    # One role with hosts, one without
    assert_raises(ArgumentError) do
      Kamal::Configuration.new @deploy.merge(servers: { "web" => %w[ web ], "workers" => { "hosts" => %w[ ] } })
    end
  end

  test "volume_args" do
    assert_equal ["--volume", "/local/path:/container/path"], @config.volume_args
  end

  test "logging args default" do
    assert_equal ["--log-opt", "max-size=\"10m\""], @config.logging_args
  end

  test "logging args with configured options" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(logging: { "options" => { "max-size" => "100m", "max-file" => 5 } }) })
    assert_equal ["--log-opt", "max-size=\"100m\"", "--log-opt", "max-file=\"5\""], @config.logging_args
  end

  test "logging args with configured driver and options" do
    config = Kamal::Configuration.new(@deploy.tap { |c| c.merge!(logging: { "driver" => "local", "options" => { "max-size" => "100m", "max-file" => 5 } }) })
    assert_equal ["--log-driver", "\"local\"", "--log-opt", "max-size=\"100m\"", "--log-opt", "max-file=\"5\""], @config.logging_args
  end

  test "erb evaluation of yml config" do
    config = Kamal::Configuration.create_from config_file: Pathname.new(File.expand_path("fixtures/deploy.erb.yml", __dir__))
    assert_equal "my-user", config.registry["username"]
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

    assert_raises(ArgumentError) do
      config = Kamal::Configuration.create_from config_file: dest_config_file
    end

    assert_nothing_raised do
      config = Kamal::Configuration.create_from config_file: dest_config_file, destination: "world"
    end
  end

  test "to_h" do
    expected_config = \
      { :roles=>["web"],
        :hosts=>["1.1.1.1", "1.1.1.2"],
        :primary_host=>"1.1.1.1",
        :version=>"missing",
        :repository=>"dhh/app",
        :absolute_image=>"dhh/app:missing",
        :service_with_version=>"app-missing",
        :ssh_options=>{ :user=>"root", log_level: :fatal, keepalive: true, keepalive_interval: 30 },
        :sshkit=>{},
        :volume_args=>["--volume", "/local/path:/container/path"],
        :builder=>{},
        :logging=>["--log-opt", "max-size=\"10m\""],
        :healthcheck=>{ "path"=>"/up", "port"=>3000, "max_attempts" => 7, "exposed_port" => 3999, "cord" => "/tmp/kamal-cord" }}

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
    assert_raises(ArgumentError) do
      Kamal::Configuration.new(@deploy.tap { |c| c.merge!(minimum_version: "10000.0.0") })
    end
  end

  test "run directory" do
    config = Kamal::Configuration.new(@deploy)
    assert_equal ".kamal", config.run_directory

    config = Kamal::Configuration.new(@deploy.merge!(run_directory: "/root/kamal"))
    assert_equal "/root/kamal", config.run_directory
  end

  test "run directory as docker volume" do
    config = Kamal::Configuration.new(@deploy)
    assert_equal "$(pwd)/.kamal", config.run_directory_as_docker_volume

    config = Kamal::Configuration.new(@deploy.merge!(run_directory: "/root/kamal"))
    assert_equal "/root/kamal", config.run_directory_as_docker_volume
  end

  test "run id" do
    SecureRandom.expects(:hex).with(16).returns("09876543211234567890098765432112")
    assert_equal "09876543211234567890098765432112", @config.run_id
  end
end
