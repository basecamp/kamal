class Kamal::Cli::Main < Kamal::Cli::Base
  desc "setup", "Setup all accessories, push the env, and deploy app to servers"
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip image build and push"
  def setup
    print_runtime do
      mutating do
        invoke_options = deploy_options

        say "Ensure Docker is installed...", :magenta
        invoke "kamal:cli:server:bootstrap", [], invoke_options

        say "Push env files...", :magenta
        invoke "kamal:cli:env:push", [], invoke_options

        invoke "kamal:cli:accessory:boot", [ "all" ], invoke_options
        deploy
      end
    end
  end

  desc "deploy", "Deploy app to servers"
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip image build and push"
  def deploy
    runtime = print_runtime do
      mutating do
        invoke_options = deploy_options

        say "Log into image registry...", :magenta
        invoke "kamal:cli:registry:login", [], invoke_options

        if options[:skip_push]
          say "Pull app image...", :magenta
          invoke "kamal:cli:build:pull", [], invoke_options
        else
          say "Build and push app image...", :magenta
          invoke "kamal:cli:build:deliver", [], invoke_options
        end

        run_hook "pre-deploy"

        say "Ensure Traefik is running...", :magenta
        invoke "kamal:cli:traefik:boot", [], invoke_options

        if KAMAL.config.role(KAMAL.config.primary_role).running_traefik?
          say "Ensure app can pass healthcheck...", :magenta
          invoke "kamal:cli:healthcheck:perform", [], invoke_options
        end

        say "Detect stale containers...", :magenta
        invoke "kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true)

        invoke "kamal:cli:app:boot", [], invoke_options

        say "Prune old containers and images...", :magenta
        invoke "kamal:cli:prune:all", [], invoke_options
      end
    end

    run_hook "post-deploy", runtime: runtime.round
  end

  desc "redeploy", "Deploy app to servers without bootstrapping servers, starting Traefik, pruning, and registry login"
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip image build and push"
  def redeploy
    runtime = print_runtime do
      mutating do
        invoke_options = deploy_options

        if options[:skip_push]
          say "Pull app image...", :magenta
          invoke "kamal:cli:build:pull", [], invoke_options
        else
          say "Build and push app image...", :magenta
          invoke "kamal:cli:build:deliver", [], invoke_options
        end

        run_hook "pre-deploy"

        say "Ensure app can pass healthcheck...", :magenta
        invoke "kamal:cli:healthcheck:perform", [], invoke_options

        say "Detect stale containers...", :magenta
        invoke "kamal:cli:app:stale_containers", [], invoke_options.merge(stop: true)

        invoke "kamal:cli:app:boot", [], invoke_options
      end
    end

    run_hook "post-deploy", runtime: runtime.round
  end

  desc "rollback [VERSION]", "Rollback app to VERSION"
  def rollback(version)
    rolled_back = false
    runtime = print_runtime do
      mutating do
        invoke_options = deploy_options

        KAMAL.config.version = version
        old_version = nil

        if container_available?(version)
          run_hook "pre-deploy"

          invoke "kamal:cli:app:boot", [], invoke_options.merge(version: version)
          rolled_back = true
        else
          say "The app version '#{version}' is not available as a container (use 'kamal app containers' for available versions)", :red
        end
      end
    end

    run_hook "post-deploy", runtime: runtime.round if rolled_back
  end

  desc "details", "Show details about all containers"
  def details
    invoke "kamal:cli:traefik:details"
    invoke "kamal:cli:app:details"
    invoke "kamal:cli:accessory:details", [ "all" ]
  end

  desc "audit", "Show audit log from servers"
  def audit
    on(KAMAL.hosts) do |host|
      puts_by_host host, capture_with_info(*KAMAL.auditor.reveal)
    end
  end

  desc "config", "Show combined config (including secrets!)"
  def config
    run_locally do
      puts Kamal::Utils.redacted(KAMAL.config.to_h).to_yaml
    end
  end

  desc "init", "Create config stub in config/deploy.yml and env stub in .env"
  option :bundle, type: :boolean, default: false, desc: "Add Kamal to the Gemfile and create a bin/kamal binstub"
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

    unless (hooks_dir = Pathname.new(File.expand_path(".kamal/hooks"))).exist?
      hooks_dir.mkpath
      Pathname.new(File.expand_path("templates/sample_hooks", __dir__)).each_child do |sample_hook|
        FileUtils.cp sample_hook, hooks_dir, preserve: true
      end
      puts "Created sample hooks in .kamal/hooks"
    end

    if options[:bundle]
      if (binstub = Pathname.new(File.expand_path("bin/kamal"))).exist?
        puts "Binstub already exists in bin/kamal (remove first to create a new one)"
      else
        puts "Adding Kamal to Gemfile and bundle..."
        run_locally do
          execute :bundle, :add, :kamal
          execute :bundle, :binstubs, :kamal
        end
        puts "Created binstub file in bin/kamal"
      end
    end
  end

  desc "envify", "Create .env by evaluating .env.erb (or .env.staging.erb -> .env.staging when using -d staging)"
  option :skip_push, aliases: "-P", type: :boolean, default: false, desc: "Skip .env file push"
  def envify
    if destination = options[:destination]
      env_template_path = ".env.#{destination}.erb"
      env_path          = ".env.#{destination}"
    else
      env_template_path = ".env.erb"
      env_path          = ".env"
    end

    File.write(env_path, ERB.new(File.read(env_template_path), trim_mode: "-").result, perm: 0600)

    unless options[:skip_push]
      reload_envs
      invoke "kamal:cli:env:push", options
    end
  end

  desc "remove", "Remove Traefik, app, accessories, and registry session from servers"
  option :confirmed, aliases: "-y", type: :boolean, default: false, desc: "Proceed without confirmation question"
  def remove
    mutating do
      confirming "This will remove all containers and images. Are you sure?" do
        invoke "kamal:cli:traefik:remove", [], options.without(:confirmed)
        invoke "kamal:cli:app:remove", [], options.without(:confirmed)
        invoke "kamal:cli:accessory:remove", [ "all" ], options
        invoke "kamal:cli:registry:logout", [], options.without(:confirmed)
      end
    end
  end

  desc "version", "Show Kamal version"
  def version
    puts Kamal::VERSION
  end

  desc "accessory", "Manage accessories (db/redis/search)"
  subcommand "accessory", Kamal::Cli::Accessory

  desc "app", "Manage application"
  subcommand "app", Kamal::Cli::App

  desc "build", "Build application image"
  subcommand "build", Kamal::Cli::Build

  desc "env", "Manage environment files"
  subcommand "env", Kamal::Cli::Env

  desc "healthcheck", "Healthcheck application"
  subcommand "healthcheck", Kamal::Cli::Healthcheck

  desc "lock", "Manage the deploy lock"
  subcommand "lock", Kamal::Cli::Lock

  desc "prune", "Prune old application images and containers"
  subcommand "prune", Kamal::Cli::Prune

  desc "registry", "Login and -out of the image registry"
  subcommand "registry", Kamal::Cli::Registry

  desc "server", "Bootstrap servers with curl and Docker"
  subcommand "server", Kamal::Cli::Server

  desc "traefik", "Manage Traefik load balancer"
  subcommand "traefik", Kamal::Cli::Traefik

  private
    def container_available?(version)
      begin
        on(KAMAL.hosts) do
          KAMAL.roles_on(host).each do |role|
            container_id = capture_with_info(*KAMAL.app(role: role).container_id_for_version(version))
            raise "Container not found" unless container_id.present?
          end
        end
      rescue SSHKit::Runner::ExecuteError => e
        if e.message =~ /Container not found/
          say "Error looking for container version #{version}: #{e.message}"
          return false
        else
          raise
        end
      end

      true
    end

    def deploy_options
      { "version" => KAMAL.config.version }.merge(options.without("skip_push"))
    end
end
