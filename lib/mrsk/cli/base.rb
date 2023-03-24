require "thor"
require "dotenv"
require "mrsk/sshkit_with_ext"

module Mrsk::Cli
  class Base < Thor
    include SSHKit::DSL

    class LockError < StandardError; end

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
      initialize_commander(options)
    end

    private
      def load_envs
        if destination = options[:destination]
          Dotenv.load(".env.#{destination}", ".env")
        else
          Dotenv.load(".env")
        end
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
        acquire_lock

        yield
      ensure
        release_lock
      end

      def acquire_lock
        if MRSK.lock_count == 0
          say "Acquiring the deploy lock"
          on(MRSK.primary_host) { execute *MRSK.lock.acquire("Automatic deploy lock", MRSK.config.version) }
        end
        MRSK.lock_count += 1
      rescue SSHKit::Runner::ExecuteError => e
        if e.message =~ /cannot create directory/
          invoke "mrsk:cli:lock:status", []
        end

        raise LockError, "Deploy lock found"
      end

      def release_lock
        MRSK.lock_count -= 1
        if MRSK.lock_count == 0
          say "Releasing the deploy lock"
          on(MRSK.primary_host) { execute *MRSK.lock.release }
        end
      end
  end
end
