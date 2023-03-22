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
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip image build and push"
  def deploy
    invoke_options = deploy_options

    runtime = print_runtime do
      say "Ensure curl and Docker are installed...", :magenta
      invoke "mrsk:cli:server:bootstrap", [], invoke_options

      say "Log into image registry...", :magenta
      invoke "mrsk:cli:registry:login", [], invoke_options

      if options[:skip_push]
        say "Pull app image...", :magenta
        invoke "mrsk:cli:build:pull", [], invoke_options
      else
        say "Build and push app image...", :magenta
        invoke "mrsk:cli:build:deliver", [], invoke_options
      end

      say "Ensure Traefik is running...", :magenta
      invoke "mrsk:cli:traefik:boot", [], invoke_options

      say "Ensure app can pass healthcheck...", :magenta
      invoke "mrsk:cli:healthcheck:perform", [], invoke_options

      invoke "mrsk:cli:app:boot", [], invoke_options

      say "Prune old containers and images...", :magenta
      invoke "mrsk:cli:prune:all", [], invoke_options
    end

    audit_broadcast "Deployed app in #{runtime.to_i} seconds" unless options[:skip_broadcast]
  end

  desc "redeploy", "Deploy app to servers without bootstrapping servers, starting Traefik, pruning, and registry login"
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip image build and push"
  def redeploy
    invoke_options = deploy_options

    runtime = print_runtime do
      if options[:skip_push]
        say "Pull app image...", :magenta
        invoke "mrsk:cli:build:pull", [], invoke_options
      else
        say "Build and push app image...", :magenta
        invoke "mrsk:cli:build:deliver", [], invoke_options
      end

      say "Ensure app can pass healthcheck...", :magenta
      invoke "mrsk:cli:healthcheck:perform", [], invoke_options

      invoke "mrsk:cli:app:boot", [], invoke_options
    end

    audit_broadcast "Redeployed app in #{runtime.to_i} seconds" unless options[:skip_broadcast]
  end

  desc "rollback [VERSION]", "Rollback app to VERSION"
  def rollback(version)
    MRSK.version = version

    if container_name_available?(MRSK.config.service_with_version)
      say "Start version #{version}, then wait #{MRSK.config.readiness_delay}s for app to boot before stopping the old version...", :magenta

      cli = self

      on(MRSK.hosts) do |host|
        old_version = capture_with_info(*MRSK.app.current_running_version).strip.presence

        execute *MRSK.app.start

        sleep MRSK.config.readiness_delay

        execute *MRSK.app.stop(version: old_version), raise_on_non_zero_exit: false
      end

      audit_broadcast "Rolled back app to version #{version}" unless options[:skip_broadcast]
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
        run_locally do
          execute :bundle, :add, :mrsk
          execute :bundle, :binstubs, :mrsk
        end
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
    if options[:confirmed] || ask("This will remove all containers and images. Are you sure?", limited_to: %w( y N ), default: "N") == "y"
      invoke "mrsk:cli:traefik:remove", [], options.without(:confirmed)
      invoke "mrsk:cli:app:remove", [], options.without(:confirmed)
      invoke "mrsk:cli:accessory:remove", [ "all" ], options
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

  desc "server", "Bootstrap servers with curl and Docker"
  subcommand "server", Mrsk::Cli::Server

  desc "traefik", "Manage Traefik load balancer"
  subcommand "traefik", Mrsk::Cli::Traefik

  private
    def container_name_available?(container_name, host: MRSK.primary_host)
      container_names = nil
      on(host) { container_names = capture_with_info(*MRSK.app.list_container_names).split("\n") }
      Array(container_names).include?(container_name)
    end

    def deploy_options
      { "version" => MRSK.config.version }.merge(options.without("skip_push"))
    end
end
