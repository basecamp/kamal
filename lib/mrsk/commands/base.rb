module Mrsk::Commands
  class Base
    delegate :redact, to: Mrsk::Utils

    attr_accessor :config

    def initialize(config)
      @config = config
    end

    def run_over_ssh(command, host:)
      ssh_command = "ssh"

      if config.ssh_proxy
        ssh_command << " -J #{config.ssh_proxy.jump_proxies}"
      end

      ssh_command << " -t #{config.ssh_user}@#{host} '#{command}'"
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

      def append(*commands)
        combine *commands, by: ">>"
      end

      def xargs(command)
        [ :xargs, command ].flatten
      end

      def docker(*args)
        args.compact.unshift :docker
      end
  end
end
