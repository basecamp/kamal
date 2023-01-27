module Mrsk::Commands
  class Base
    delegate :redact, to: Mrsk::Utils

    attr_accessor :config

    def initialize(config)
      @config = config
    end

    private
      def combine(*commands, by: "&&")
        commands
          .compact
          .collect { |command| Array(command) + [ by ] }.flatten # Join commands
          .tap     { |commands| commands.pop } # Remove trailing combiner
      end

      def chain(*commands)
        combine *commands, by: ";"
      end

      def pipe(*commands)
        combine *commands, by: "|"
      end

      def docker(*args)
        args.compact.unshift :docker
      end

      def run_over_ssh(command, host:)
        "ssh -t #{config.ssh_user}@#{host} '#{command}'"
      end
  end
end
