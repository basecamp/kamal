require "sshkit"

module Mrsk::Commands
  class Base
    attr_accessor :config

    def initialize(config)
      @config = config
    end

    private
      def combine(*commands)
        commands
          .collect { |command| command + [ "&&" ] }.flatten # Join commands with &&
          .tap     { |commands| commands.pop } # Remove trailing &&
      end

      def docker(*args)
        args.compact.unshift :docker
      end
  end
end
