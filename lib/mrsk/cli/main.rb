require "mrsk/cli/base"

require "mrsk/cli/app"
require "mrsk/cli/build"
require "mrsk/cli/prune"
require "mrsk/cli/registry"
require "mrsk/cli/server"
require "mrsk/cli/traefik"

class Mrsk::Cli::Main < Mrsk::Cli::Base
  desc "deploy", "Deploy the app to servers"
  def deploy
    print_runtime do
      invoke "mrsk:cli:server:bootstrap"
      invoke "mrsk:cli:registry:login"
      invoke "mrsk:cli:build:deliver"
      invoke "mrsk:cli:traefik:boot"
      invoke "mrsk:cli:app:stop"
      invoke "mrsk:cli:app:boot"
      invoke "mrsk:cli:prune:all"
    end
  end

  desc "redeploy", "Deploy new version of the app to servers (without bootstrapping servers, starting Traefik, pruning, and registry login)"
  def redeploy
    print_runtime do
      invoke "mrsk:cli:build:deliver"
      invoke "mrsk:cli:app:stop"
      invoke "mrsk:cli:app:boot"
    end
  end

  desc "rollback [VERSION]", "Rollback the app to VERSION (that must already be on servers)"
  def rollback(version)
    invoke "mrsk:cli:app:restart"
  end

  desc "details", "Display details about Traefik and app containers"
  def details
    invoke "mrsk:cli:traefik:details"
    invoke "mrsk:cli:app:details"
  end

  desc "install", "Create config stub in config/deploy.yml and binstub in bin/mrsk"
  option :skip_binstub, type: :boolean, default: false, desc: "Skip adding MRSK to the Gemfile and creating bin/mrsk binstub"
  def install
    require "fileutils"

    if (deploy_file = Pathname.new(File.expand_path("config/deploy.yml"))).exist?
      puts "Config file already exists in config/deploy.yml (remove first to create a new one)"
    else
      FileUtils.cp_r Pathname.new(File.expand_path("templates/deploy.yml", __dir__)), deploy_file
      puts "Created configuration file in config/deploy.yml"
    end

    unless options[:skip_binstub]
      if (binstub = Pathname.new(File.expand_path("bin/mrsk"))).exist?
        puts "Binstub already exists in bin/mrsk (remove first to create a new one)"
      else
        `bundle add mrsk`
        `bundle binstubs mrsk`
        puts "Created binstub file in bin/mrsk"
      end
    end
  end

  desc "remove", "Remove Traefik, app, and registry session from servers"
  def remove
    invoke "mrsk:cli:traefik:remove"
    invoke "mrsk:cli:app:remove"
    invoke "mrsk:cli:registry:logout"
  end

  desc "version", "Display the MRSK version"
  def version
    puts Mrsk::VERSION
  end

  desc "app", "Manage the application"
  subcommand "app", Mrsk::Cli::App

  desc "build", "Build the application image"
  subcommand "build", Mrsk::Cli::Build

  desc "prune", "Prune old application images and containers"
  subcommand "prune", Mrsk::Cli::Prune

  desc "registry", "Login and out of the image registry"
  subcommand "registry", Mrsk::Cli::Registry

  desc "server", "Bootstrap servers with Docker"
  subcommand "server", Mrsk::Cli::Server

  desc "traefik", "Manage the Traefik load balancer"
  subcommand "traefik", Mrsk::Cli::Traefik
end
