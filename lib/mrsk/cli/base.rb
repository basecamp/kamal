require "thor"
require "sshkit"
require "sshkit/dsl"

module Mrsk::Cli
  class Base < Thor
    include SSHKit::DSL

    def self.exit_on_failure?() true end

    class_option :verbose, type: :boolean, aliases: "-v", desc: "Detailed logging"

    def initialize(*)
      super
      MRSK.verbose = options[:verbose]
    end

    private
      def print_runtime
        started_at = Time.now
        yield
      ensure
        runtime = Time.now - started_at
        puts "  Finished all in #{sprintf("%.1f seconds", runtime)}"
      end
  end
end
