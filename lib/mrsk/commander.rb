require "mrsk/configuration"
require "mrsk/commands/app"
require "mrsk/commands/builder"
require "mrsk/commands/prune"
require "mrsk/commands/traefik"
require "mrsk/commands/registry"

class Mrsk::Commander
  attr_accessor :config_file, :destination, :verbose

  def initialize(config_file: nil, destination: nil, verbose: false)
    @config_file, @destination, @verbose = config_file, destination, verbose
  end

  def config
    @config ||= Mrsk::Configuration.create_from(config_file, destination: destination).tap { |config| setup_with(config) }
  end

  def hosts=(hosts)
    @hosts = hosts if hosts.present?
  end

  def roles=(role_names)
    @hosts = config.roles.select { |r| role_names.include?(r.name) }.flat_map(&:hosts) if role_names.present?
  end

  def hosts
    @hosts || config.all_hosts
  end

  def traefik_hosts
    @hosts || config.traefik_hosts
  end


  def app
    @app ||= Mrsk::Commands::App.new(config)
  end

  def builder
    @builder ||= Mrsk::Commands::Builder.new(config)
  end

  def traefik
    @traefik ||= Mrsk::Commands::Traefik.new(config)
  end

  def registry
    @registry ||= Mrsk::Commands::Registry.new(config)
  end

  def prune
    @prune ||= Mrsk::Commands::Prune.new(config)
  end


  def verbosity(level) 
    old_level = SSHKit.config.output_verbosity
    SSHKit.config.output_verbosity = level
    yield
  ensure
    SSHKit.config.output_verbosity = old_level
  end

  private
    # Lazy setup of SSHKit
    def setup_with(config)
      SSHKit::Backend::Netssh.configure { |ssh| ssh.ssh_options = config.ssh_options }
      SSHKit.config.command_map[:docker] = "docker" # No need to use /usr/bin/env, just clogs up the logs
      SSHKit.config.output_verbosity = :debug if verbose
    end
end
