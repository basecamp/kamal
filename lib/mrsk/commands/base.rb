module Mrsk::Commands
  class Base
    delegate :sensitive, :argumentize, to: Mrsk::Utils

    DOCKER_HEALTH_STATUS_FORMAT = "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'"

    attr_accessor :config

    def initialize(config)
      @config = config
    end

    def run_over_ssh(*command, host:)
      "ssh".tap do |cmd|
        cmd << " -J #{config.ssh_proxy.jump_proxies}" if config.ssh_proxy
        cmd << " -t #{config.ssh_user}@#{host} '#{command.join(" ")}'"
      end
    end

    def container_id_for(container_name:)
      docker :container, :ls, "--all", "--filter", "name=^#{container_name}$", "--quiet"
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

      def write(*commands)
        combine *commands, by: ">"
      end

      def xargs(command)
        [ :xargs, command ].flatten
      end

      def docker(*args)
        args.compact.unshift :docker
      end
  end
end
