require "thor"
require "dotenv"
require "kamal/sshkit_with_ext"

module Kamal::Cli
  class Base < Thor
    include SSHKit::DSL

    def self.exit_on_failure?() true end

    class_option :verbose, type: :boolean, aliases: "-v", desc: "Detailed logging"
    class_option :quiet, type: :boolean, aliases: "-q", desc: "Minimal logging"

    class_option :version, desc: "Run commands against a specific app version"

    class_option :primary, type: :boolean, aliases: "-p", desc: "Run commands only on primary host instead of all"
    class_option :hosts, aliases: "-h", desc: "Run commands on these hosts instead of all (separate by comma)"
    class_option :roles, aliases: "-r", desc: "Run commands on these roles instead of all (separate by comma)"

    class_option :config_file, aliases: "-c", default: "config/deploy.yml", desc: "Path to config file"
    class_option :destination, aliases: "-d", desc: "Specify destination to be used for config file (staging -> deploy.staging.yml)"

    class_option :skip_hooks, aliases: "-H", type: :boolean, default: false, desc: "Don't run hooks"

    def initialize(*)
      super
      load_envs
      initialize_commander(options_with_subcommand_class_options)
    end

    private
      def load_envs
        if destination = options[:destination]
          Dotenv.load(".env.#{destination}", ".env")
        else
          Dotenv.load(".env")
        end
      end

      def options_with_subcommand_class_options
        options.merge(@_initializer.last[:class_options] || {})
      end

    def config_file_path
      path = File.expand_path(options[:config_file])
      return "#{path}.erb" if File.exist?("#{path}.erb")

      path
    end

      def initialize_commander(options)
        KAMAL.tap do |commander|
          if options[:verbose]
            ENV["VERBOSE"] = "1" # For backtraces via cli/start
            commander.verbosity = :debug
          end

          if options[:quiet]
            commander.verbosity = :error
          end

          commander.configure \
            config_file: Pathname.new(File.expand_path(config_file_path)),
            destination: options[:destination],
            version: options[:version]

          commander.specific_hosts    = options[:hosts]&.split(",")
          commander.specific_roles    = options[:roles]&.split(",")
          commander.specific_primary! if options[:primary]
        end
      end

      def print_runtime
        started_at = Time.now
        yield
        return Time.now - started_at
      ensure
        runtime = Time.now - started_at
        puts "  Finished all in #{sprintf("%.1f seconds", runtime)}"
      end

      def mutating
        return yield if KAMAL.holding_lock?

        KAMAL.config.ensure_env_available

        run_hook "pre-connect"

        ensure_run_directory

        acquire_lock

        begin
          yield
        rescue
          if KAMAL.hold_lock_on_error?
            error "  \e[31mDeploy lock was not released\e[0m"
          else
            release_lock
          end

          raise
        end

        release_lock
      end

      def acquire_lock
        raise_if_locked do
          say "Acquiring the deploy lock...", :magenta
          on(KAMAL.primary_host) { execute *KAMAL.lock.acquire("Automatic deploy lock", KAMAL.config.version), verbosity: :debug }
        end

        KAMAL.holding_lock = true
      end

      def release_lock
        say "Releasing the deploy lock...", :magenta
        on(KAMAL.primary_host) { execute *KAMAL.lock.release, verbosity: :debug }

        KAMAL.holding_lock = false
      end

      def raise_if_locked
        yield
      rescue SSHKit::Runner::ExecuteError => e
        if e.message =~ /cannot create directory/
          on(KAMAL.primary_host) { puts capture_with_debug(*KAMAL.lock.status) }
          raise LockError, "Deploy lock found"
        else
          raise e
        end
      end

      def hold_lock_on_error
        if KAMAL.hold_lock_on_error?
          yield
        else
          KAMAL.hold_lock_on_error = true
          yield
          KAMAL.hold_lock_on_error = false
        end
      end

      def run_hook(hook, **extra_details)
        if !options[:skip_hooks] && KAMAL.hook.hook_exists?(hook)
          details = { hosts: KAMAL.hosts.join(","), command: command, subcommand: subcommand }

          say "Running the #{hook} hook...", :magenta
          run_locally do
            KAMAL.with_verbosity(:debug) { execute *KAMAL.hook.run(hook, **details, **extra_details) }
          rescue SSHKit::Command::Failed
            raise HookError.new("Hook `#{hook}` failed")
          end
        end
      end

      def command
        @kamal_command ||= begin
          invocation_class, invocation_commands = *first_invocation
          if invocation_class == Kamal::Cli::Main
            invocation_commands[0]
          else
            Kamal::Cli::Main.subcommand_classes.find { |command, clazz| clazz == invocation_class }[0]
          end
        end
      end

      def subcommand
        @kamal_subcommand ||= begin
          invocation_class, invocation_commands = *first_invocation
          invocation_commands[0] if invocation_class != Kamal::Cli::Main
        end
      end

      def first_invocation
        instance_variable_get("@_invocations").first
      end

      def ensure_run_directory
        on(KAMAL.hosts) do
          execute(*KAMAL.server.ensure_run_directory)
        end
      end
    end
end
