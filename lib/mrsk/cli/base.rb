require "thor"
require "dotenv"
require "mrsk/sshkit_with_ext"

module Mrsk::Cli
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

    class_option :skip_broadcast, aliases: "-B", type: :boolean, default: false, desc: "Skip audit broadcasts"

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

      def initialize_commander(options)
        MRSK.tap do |commander|
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
        return Time.now - started_at
      ensure
        runtime = Time.now - started_at
        puts "  Finished all in #{sprintf("%.1f seconds", runtime)}"
      end

      def audit_broadcast(line)
        run_locally { execute *MRSK.auditor.broadcast(line), verbosity: :debug }
      end

      def with_lock
        if MRSK.holding_lock?
          yield
        else
          acquire_lock

          begin
            yield
          rescue
            if MRSK.hold_lock_on_error?
              error "  \e[31mDeploy lock was not released\e[0m"
            else
              release_lock
            end

            raise
          end

          release_lock
        end
      end

      def acquire_lock
        say "Acquiring the deploy lock"
        on(MRSK.primary_host) { execute *MRSK.lock.acquire("Automatic deploy lock", MRSK.config.version) }

        MRSK.holding_lock = true
      rescue SSHKit::Runner::ExecuteError => e
        if e.message =~ /cannot create directory/
          on(MRSK.primary_host) { execute *MRSK.lock.status }
          raise LockError, "Deploy lock found"
        else
          raise e
        end
      end

      def release_lock
        say "Releasing the deploy lock"
        on(MRSK.primary_host) { execute *MRSK.lock.release }

        MRSK.holding_lock = false
      end

      def hold_lock_on_error
        if MRSK.hold_lock_on_error?
          yield
        else
          MRSK.hold_lock_on_error = true
          yield
          MRSK.hold_lock_on_error = false
        end
      end
  end
end
