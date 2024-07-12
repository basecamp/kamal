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
    class_option :hosts, aliases: "-h", desc: "Run commands on these hosts instead of all (separate by comma, supports wildcards with *)"
    class_option :roles, aliases: "-r", desc: "Run commands on these roles instead of all (separate by comma, supports wildcards with *)"

    class_option :config_file, aliases: "-c", default: "config/deploy.yml", desc: "Path to config file"
    class_option :destination, aliases: "-d", desc: "Specify destination to be used for config file (staging -> deploy.staging.yml)"

    class_option :skip_hooks, aliases: "-H", type: :boolean, default: false, desc: "Don't run hooks"

    def initialize(*)
      super
      @original_env = ENV.to_h.dup
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

      def reload_envs
        ENV.clear
        ENV.update(@original_env)
        load_envs
      end

      def options_with_subcommand_class_options
        options.merge(@_initializer.last[:class_options] || {})
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
            config_file: Pathname.new(File.expand_path(options[:config_file])),
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
        Time.now - started_at
      ensure
        runtime = Time.now - started_at
        puts "  Finished all in #{sprintf("%.1f seconds", runtime)}"
      end

      def with_lock
        if KAMAL.holding_lock?
          yield
        else
          ensure_run_and_locks_directory

          acquire_lock

          begin
            yield
          rescue
            begin
              release_lock
            rescue => e
              say "Error releasing the deploy lock: #{e.message}", :red
            end
            raise
          end

          release_lock
        end
      end

      def confirming(question)
        return yield if options[:confirmed]

        if ask(question, limited_to: %w[ y N ], default: "N") == "y"
          yield
        else
          say "Aborted", :red
        end
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
          say "Deploy lock already in place!", :red
          on(KAMAL.primary_host) { puts capture_with_debug(*KAMAL.lock.status) }
          raise LockError, "Deploy lock found. Run 'kamal lock help' for more information"
        else
          raise e
        end
      end

      def run_hook(hook, **extra_details)
        if !options[:skip_hooks] && KAMAL.hook.hook_exists?(hook)
          details = { hosts: KAMAL.hosts.join(","), command: command, subcommand: subcommand }

          say "Running the #{hook} hook...", :magenta
          run_locally do
            execute *KAMAL.hook.run(hook, **details, **extra_details)
          rescue SSHKit::Command::Failed => e
            raise HookError.new("Hook `#{hook}` failed:\n#{e.message}")
          end
        end
      end

      def on(*args, &block)
        if !KAMAL.connected?
          run_hook "pre-connect"
          KAMAL.connected = true
        end

        super
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

      def ensure_run_and_locks_directory
        on(KAMAL.hosts) do
          execute(*KAMAL.server.ensure_run_directory)
        end

        on(KAMAL.primary_host) do
          execute(*KAMAL.lock.ensure_locks_directory)
        end
      end
  end
end
