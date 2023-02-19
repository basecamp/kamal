class Mrsk::Cli::Main < Mrsk::Cli::Base
  desc "setup", "Setup all accessories and deploy app to servers"
  def setup
    print_runtime do
      invoke "mrsk:cli:server:bootstrap"
      invoke "mrsk:cli:accessory:boot", [ "all" ]
      deploy
    end
  end

  desc "deploy", "Deploy app to servers"
  def deploy
    runtime = print_runtime do
      say "Ensure Docker is installed...", :magenta
      invoke "mrsk:cli:server:bootstrap"

      say "Log into image registry...", :magenta
      invoke "mrsk:cli:registry:login"

      say "Build and push app image...", :magenta
      invoke "mrsk:cli:build:deliver"

      say "Ensure Traefik is running...", :magenta
      invoke "mrsk:cli:traefik:boot"

      say "Ensure app can pass healthcheck...", :magenta
      invoke "mrsk:cli:healthcheck:perform"

      invoke "mrsk:cli:app:boot"

      say "Prune old containers and images...", :magenta
      invoke "mrsk:cli:prune:all"
    end

    audit_broadcast "Deployed app in #{runtime.to_i} seconds"
  end

  desc "redeploy", "Deploy app to servers without bootstrapping servers, starting Traefik, pruning, and registry login"
  def redeploy
    runtime = print_runtime do
      say "Build and push app image...", :magenta
      invoke "mrsk:cli:build:deliver"

      say "Ensure app can pass healthcheck...", :magenta
      invoke "mrsk:cli:healthcheck:perform"

      invoke "mrsk:cli:app:boot"
    end

    audit_broadcast "Redeployed app in #{runtime.to_i} seconds"
  end

  desc "rollback [VERSION]", "Rollback app to VERSION"
  def rollback(version)
    MRSK.version = version

    if container_name_available?(MRSK.config.service_with_version)
      say "Stop current version, then start version #{version}...", :magenta

      on(MRSK.hosts) do |host|
        execute *MRSK.app.stop, raise_on_non_zero_exit: false
        execute *MRSK.app.start
      end

      audit_broadcast "Rolled back app to version #{version}"
    else
      say "The app version '#{version}' is not available as a container (use 'mrsk app containers' for available versions)", :red
    end
  end

  desc "details", "Show details about all containers"
  def details
    invoke "mrsk:cli:traefik:details"
    invoke "mrsk:cli:app:details"
    invoke "mrsk:cli:accessory:details", [ "all" ]
  end

  desc "audit", "Show audit log from servers"
  def audit
    on(MRSK.hosts) do |host|
      puts_by_host host, capture_with_info(*MRSK.auditor.reveal)
    end
  end

  desc "config", "Show combined config (including secrets!)"
  def config
    run_locally do
      puts MRSK.config.to_h.to_yaml
    end
  end

  desc "init", "Create config stub in config/deploy.yml and env stub in .env"
  option :bundle, type: :boolean, default: false, desc: "Add MRSK to the Gemfile and create a bin/mrsk binstub"
  def init
    require "fileutils"

    if (deploy_file = Pathname.new(File.expand_path("config/deploy.yml"))).exist?
      puts "Config file already exists in config/deploy.yml (remove first to create a new one)"
    else
      FileUtils.mkdir_p deploy_file.dirname
      FileUtils.cp_r Pathname.new(File.expand_path("templates/deploy.yml", __dir__)), deploy_file
      puts "Created configuration file in config/deploy.yml"
    end

    unless (deploy_file = Pathname.new(File.expand_path(".env"))).exist?
      FileUtils.cp_r Pathname.new(File.expand_path("templates/template.env", __dir__)), deploy_file
      puts "Created .env file"
    end

    if options[:bundle]
      if (binstub = Pathname.new(File.expand_path("bin/mrsk"))).exist?
        puts "Binstub already exists in bin/mrsk (remove first to create a new one)"
      else
        puts "Adding MRSK to Gemfile and bundle..."
        `bundle add mrsk`
        `bundle binstubs mrsk`
        puts "Created binstub file in bin/mrsk"
      end
    end
  end

  desc "envify", "Create .env by evaluating .env.erb (or .env.staging.erb -> .env.staging when using -d staging)"
  def envify
    if destination = options[:destination]
      env_template_path = ".env.#{destination}.erb"
      env_path          = ".env.#{destination}"
    else
      env_template_path = ".env.erb"
      env_path          = ".env"
    end

    File.write(env_path, ERB.new(File.read(env_template_path)).result, perm: 0600)
  end

  desc "remove", "Remove Traefik, app, accessories, and registry session from servers"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def remove
    if options[:confirmed] || ask(remove_confirmation_question, limited_to: %w( y N ), default: "N") == "y"
      invoke "mrsk:cli:traefik:remove", [], options.without(:confirmed)
      invoke "mrsk:cli:app:remove", [], options.without(:confirmed)
      invoke "mrsk:cli:accessory:remove", [ "all" ]
      invoke "mrsk:cli:registry:logout", [], options.without(:confirmed)
    end
  end

  desc "version", "Show MRSK version"
  def version
    puts Mrsk::VERSION
  end

  desc "accessory", "Manage accessories (db/redis/search)"
  subcommand "accessory", Mrsk::Cli::Accessory

  desc "app", "Manage application"
  subcommand "app", Mrsk::Cli::App

  desc "build", "Build application image"
  subcommand "build", Mrsk::Cli::Build

  desc "healthcheck", "Healthcheck application"
  subcommand "healthcheck", Mrsk::Cli::Healthcheck

  desc "prune", "Prune old application images and containers"
  subcommand "prune", Mrsk::Cli::Prune

  desc "registry", "Login and -out of the image registry"
  subcommand "registry", Mrsk::Cli::Registry

  desc "server", "Bootstrap servers with Docker"
  subcommand "server", Mrsk::Cli::Server

  desc "traefik", "Manage Traefik load balancer"
  subcommand "traefik", Mrsk::Cli::Traefik

  private
    def container_name_available?(container_name, host: MRSK.primary_host)
      container_names = nil
      on(host) { container_names = capture_with_info(*MRSK.app.list_container_names).split("\n") }
      Array(container_names).include?(container_name)
    end

    def remove_confirmation_question      
      "This will remove all containers and images. " +
      (MRSK.config.accessories.any? ? "Including #{MRSK.config.accessories.collect(&:name).to_sentence}. " : "") +
      "Are you sure?"
    end
end
