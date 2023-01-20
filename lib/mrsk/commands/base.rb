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

      def pipe(*commands)
        combine *commands, by: "|"
      end

      def docker(*args)
        args.compact.unshift :docker
      end
  end
end
