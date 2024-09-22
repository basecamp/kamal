require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/blank"

class Kamal::Commander
  attr_accessor :verbosity, :holding_lock, :connected
  delegate :hosts, :roles, :primary_host, :primary_role, :roles_on, :proxy_hosts, :accessory_hosts, to: :specifics

  def initialize
    self.verbosity = :info
    self.holding_lock = false
    self.connected = false
    @specifics = nil
  end

  def config
    @config ||= Kamal::Configuration.create_from(**@config_kwargs).tap do |config|
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

  attr_reader :specific_roles, :specific_hosts

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
    if role_names.present?
      @specific_roles = Kamal::Utils.filter_specific_items(role_names, config.roles)

      if @specific_roles.empty?
        raise ArgumentError, "No --roles match for #{role_names.join(',')}"
      end

      @specific_roles
    end
  end

  def specific_hosts=(hosts)
    @specifics = nil
    if hosts.present?
      @specific_hosts = Kamal::Utils.filter_specific_items(hosts, config.all_hosts)

      if @specific_hosts.empty?
        raise ArgumentError, "No --hosts match for #{hosts.join(',')}"
      end

      @specific_hosts
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

  def accessories_on(host)
    config.accessories.select { |accessory| accessory.hosts.include?(host.to_s) }.map(&:name)
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
    @builder ||= Kamal::Commands::Builder.new(config)
  end

  def docker
    @docker ||= Kamal::Commands::Docker.new(config)
  end

  def hook
    @hook ||= Kamal::Commands::Hook.new(config)
  end

  def lock
    @lock ||= Kamal::Commands::Lock.new(config)
  end

  def proxy
    @proxy ||= Kamal::Commands::Proxy.new(config)
  end

  def prune
    @prune ||= Kamal::Commands::Prune.new(config)
  end

  def registry
    @registry ||= Kamal::Commands::Registry.new(config)
  end

  def server
    @server ||= Kamal::Commands::Server.new(config)
  end

  def alias(name)
    config.aliases[name]
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

  def boot_strategy
    if config.boot.limit.present?
      { in: :groups, limit: config.boot.limit, wait: config.boot.wait }
    else
      {}
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
        sshkit.ssh_options = config.ssh.options
      end
      SSHKit.config.command_map[:docker] = "docker" # No need to use /usr/bin/env, just clogs up the logs
      SSHKit.config.output_verbosity = verbosity
    end

    def specifics
      @specifics ||= Kamal::Commander::Specifics.new(config, specific_hosts, specific_roles)
    end
end
