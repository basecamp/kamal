require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"

class Kamal::Commander
  attr_accessor :verbosity, :holding_lock, :hold_lock_on_error

  def initialize
    self.verbosity = :info
    self.holding_lock = false
    self.hold_lock_on_error = false
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

  attr_reader :specific_roles, :specific_hosts

  def specific_primary!
    self.specific_hosts = [ config.primary_host ]
  end

  def specific_roles=(role_names)
    @specific_roles = config.roles.select { |r| role_names.include?(r.name) } if role_names.present?
  end

  def specific_hosts=(hosts)
    @specific_hosts = config.all_hosts & hosts if hosts.present?
  end

  def primary_host
    specific_hosts&.first || specific_roles&.first&.primary_host || config.primary_host
  end

  def primary_role
    roles_on(primary_host).first
  end

  def roles
    (specific_roles || config.roles).select do |role|
      ((specific_hosts || config.all_hosts) & role.hosts).any?
    end
  end

  def hosts
    (specific_hosts || config.all_hosts).select do |host|
      (specific_roles || config.roles).flat_map(&:hosts).include?(host)
    end
  end

  def roles_on(host)
    roles.select { |role| role.hosts.include?(host.to_s) }.map(&:name)
  end

  def traefik_hosts
    specific_hosts || config.traefik_hosts
  end

  def accessory_hosts
    specific_hosts || config.accessories.flat_map(&:hosts)
  end

  def accessory_names
    config.accessories&.collect(&:name) || []
  end

  def accessories_on(host)
    config.accessories.select { |accessory| accessory.hosts.include?(host.to_s) }.map(&:name)
  end


  def app(role: nil)
    Kamal::Commands::App.new(config, role: role)
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

  def healthcheck
    @healthcheck ||= Kamal::Commands::Healthcheck.new(config)
  end

  def hook
    @hook ||= Kamal::Commands::Hook.new(config)
  end

  def lock
    @lock ||= Kamal::Commands::Lock.new(config)
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

  def traefik
    @traefik ||= Kamal::Commands::Traefik.new(config)
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

  def hold_lock_on_error?
    self.hold_lock_on_error
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
end
