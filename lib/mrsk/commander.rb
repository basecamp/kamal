require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"

class Mrsk::Commander
  attr_accessor :verbosity, :holding_lock, :hold_lock_on_error

  def initialize
    self.verbosity = :info
    self.holding_lock = false
    self.hold_lock_on_error = false
  end

  def config
    @config ||= Mrsk::Configuration.create_from(**@config_kwargs).tap do |config|
      @config_kwargs = nil
      configure_sshkit_with(config)
    end
  end

  def configure(**kwargs)
    @config, @config_kwargs = nil, kwargs
  end

  attr_reader :specific_roles, :specific_hosts

  def specific_primary!
    self.specific_hosts = [ config.primary_web_host ]
  end

  def specific_roles=(role_names)
    @specific_roles = config.roles.select { |r| role_names.include?(r.name) } if role_names.present?
  end

  def specific_hosts=(hosts)
    @specific_hosts = config.all_hosts & hosts if hosts.present?
  end

  def primary_host
    specific_hosts&.first || specific_roles&.first&.primary_host || config.primary_web_host
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

  def boot_strategy
    if config.boot.limit.present?
      { in: :groups, limit: config.boot.limit, wait: config.boot.wait }
    else
      {}
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


  def app(role: nil)
    Mrsk::Commands::App.new(config, role: role)
  end

  def accessory(name)
    Mrsk::Commands::Accessory.new(config, name: name)
  end

  def auditor(role: nil)
    Mrsk::Commands::Auditor.new(config, role: role)
  end

  def builder
    @builder ||= Mrsk::Commands::Builder.new(config)
  end

  def docker
    @docker ||= Mrsk::Commands::Docker.new(config)
  end

  def healthcheck
    @healthcheck ||= Mrsk::Commands::Healthcheck.new(config)
  end

  def prune
    @prune ||= Mrsk::Commands::Prune.new(config)
  end

  def registry
    @registry ||= Mrsk::Commands::Registry.new(config)
  end

  def traefik
    @traefik ||= Mrsk::Commands::Traefik.new(config)
  end

  def lock
    @lock ||= Mrsk::Commands::Lock.new(config)
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

  def holding_lock?
    self.holding_lock
  end

  def hold_lock_on_error?
    self.hold_lock_on_error
  end

  private
    # Lazy setup of SSHKit
    def configure_sshkit_with(config)
      SSHKit::Backend::Netssh.configure { |ssh| ssh.ssh_options = config.ssh_options }
      SSHKit.config.command_map[:docker] = "docker" # No need to use /usr/bin/env, just clogs up the logs
      SSHKit.config.output_verbosity = verbosity
    end
end
