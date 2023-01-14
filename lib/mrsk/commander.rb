require "mrsk/configuration"
require "mrsk/commands/app"
require "mrsk/commands/builder"
require "mrsk/commands/prune"
require "mrsk/commands/traefik"
require "mrsk/commands/registry"

class Mrsk::Commander
  attr_reader :config
  attr_accessor :verbose

  def initialize(config_file:)
    @config_file = config_file
  end

  def config
    @config ||= Mrsk::Configuration.load_file(@config_file).tap { |config| setup_with(config) }
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
