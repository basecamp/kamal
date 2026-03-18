require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"

class Kamal::Commander
  attr_accessor :verbosity, :holding_lock, :connected
  attr_reader :specific_roles, :specific_hosts
  delegate :hosts, :roles, :primary_host, :primary_role, :roles_on, :app_hosts, :proxy_hosts, :accessory_hosts, to: :specifics

  def initialize
    reset
  end

  def reset
    self.verbosity = :info
    self.holding_lock = ENV["KAMAL_LOCK"] == "true"
    self.connected = false
    @specifics = @specific_roles = @specific_hosts = nil
    @config = @config_kwargs = nil
    @commands = {}
  end

  def config
    @config ||= Kamal::Configuration.create_from(**@config_kwargs.to_h).tap do |config|
      @config_kwargs = nil
      configure_sshkit_with(config)
    end
  end

  def configure(**kwargs)
    @config, @config_kwargs = nil, kwargs
  end

  def configured?
    @config || @config_kwargs
  end

  def specific_primary!
    @specifics = nil
    if specific_roles.present?
      self.specific_hosts = [ specific_roles.first.primary_host ]
    else
      self.specific_hosts = [ config.primary_host ]
    end
  end

  def specific_roles=(role_names)
    @specifics = nil
    @specific_roles = if role_names.present?
      filtered = Kamal::Utils.filter_specific_items(role_names, config.roles)
      raise ArgumentError, "No --roles match for #{role_names.join(',')}" if filtered.empty?
      filtered
    end
  end

  def specific_hosts=(hosts)
    @specifics = nil
    @specific_hosts = if hosts.present?
      filtered = Kamal::Utils.filter_specific_items(hosts, config.all_hosts)
      raise ArgumentError, "No --hosts match for #{hosts.join(',')}" if filtered.empty?
      filtered
    end
  end

  def with_specific_hosts(hosts)
    original_hosts, self.specific_hosts = specific_hosts, hosts
    yield
  ensure
    self.specific_hosts = original_hosts
  end

  def accessory_names
    config.accessories&.collect(&:name) || []
  end

  def app(role: nil, host: nil)
    Kamal::Commands::App.new(config, role: role, host: host)
  end

  def accessory(name)
    Kamal::Commands::Accessory.new(config, name: name)
  end

  def auditor(**details)
    Kamal::Commands::Auditor.new(config, **details)
  end

  def builder
    @commands[:builder] ||= Kamal::Commands::Builder.new(config)
  end

  def docker
    @commands[:docker] ||= Kamal::Commands::Docker.new(config)
  end

  def hook
    @commands[:hook] ||= Kamal::Commands::Hook.new(config)
  end

  def lock
    @commands[:lock] ||= Kamal::Commands::Lock.new(config)
  end

  def proxy(host)
    Kamal::Commands::Proxy.new(config, host: host)
  end

  def prune
    @commands[:prune] ||= Kamal::Commands::Prune.new(config)
  end

  def registry
    @commands[:registry] ||= Kamal::Commands::Registry.new(config)
  end

  def server
    @commands[:server] ||= Kamal::Commands::Server.new(config)
  end

  def alias(name)
    config.aliases[name]
  end

  def resolve_alias(name)
    if @config
      @config.aliases[name]&.command
    else
      raw_config = Kamal::Configuration.load_raw_config(**@config_kwargs.to_h.slice(:config_file, :destination))
      raw_config[:aliases]&.dig(name)
    end
  end

  def with_verbosity(level)
    old_level = self.verbosity

    self.verbosity = level
    SSHKit.config.output_verbosity = level

    yield
  ensure
    self.verbosity = old_level
    SSHKit.config.output_verbosity = old_level
  end

  def otel_event(name, **attrs)
    config if configured? && !@config # ensure shipper is initialized
    @otel_shipper&.event(name, **attrs)
  end

  def otel_shutdown
    if @otel_shipper
      @otel_shipper.shutdown
      @otel_shipper = nil
    end

    if @original_stdout
      $stdout = @original_stdout
      $stderr = @original_stderr
      @original_stdout = @original_stderr = nil
    end
  end

  def holding_lock?
    self.holding_lock
  end

  def connected?
    self.connected
  end

  private
    # Lazy setup of SSHKit
    def configure_sshkit_with(config)
      SSHKit::Backend::Netssh.pool.idle_timeout = config.sshkit.pool_idle_timeout
      SSHKit::Backend::Netssh.configure do |sshkit|
        sshkit.max_concurrent_starts = config.sshkit.max_concurrent_starts
        sshkit.dns_retries = config.sshkit.dns_retries
        sshkit.ssh_options = config.ssh.options
      end
      SSHKit.config.command_map[:docker] = "docker" # No need to use /usr/bin/env, just clogs up the logs
      SSHKit.config.output_verbosity = verbosity

      configure_otel_with(config)
    end

    def configure_otel_with(config)
      return unless config.otel.enabled?

      @otel_shipper = Kamal::OtelShipper.new(
        endpoint: config.otel.endpoint,
        service_namespace: config.otel.service_namespace,
        environment: config.otel.environment,
        version: config.version,
        performer: `git config user.name`.chomp.presence || ENV["USER"]
      )

      @original_stdout = $stdout
      @original_stderr = $stderr
      $stdout = Kamal::TeeIo.new(@original_stdout, @otel_shipper)
      $stderr = Kamal::TeeIo.new(@original_stderr, @otel_shipper)
    rescue => e
      @otel_shipper = nil
      $stderr.puts "OTel setup failed (#{e.message}), continuing without deploy log shipping"
    end

    def specifics
      @specifics ||= Kamal::Commander::Specifics.new(config, specific_hosts, specific_roles)
    end
end
