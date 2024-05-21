module Kamal::Commands
  class Base
    delegate :sensitive, :argumentize, to: Kamal::Utils

    DOCKER_HEALTH_STATUS_FORMAT = "'{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}'"

    attr_accessor :config

    def initialize(config)
      @config = config
    end

    def run_over_ssh(*command, host:)
      "ssh".tap do |cmd|
        if config.ssh.proxy && config.ssh.proxy.is_a?(Net::SSH::Proxy::Jump)
          cmd << " -J #{config.ssh.proxy.jump_proxies}"
        elsif config.ssh.proxy && config.ssh.proxy.is_a?(Net::SSH::Proxy::Command)
          cmd << " -o ProxyCommand='#{config.ssh.proxy.command_line_template}'"
        end
        cmd << " -t #{config.ssh.user}@#{host} -p #{config.ssh.port} '#{command.join(" ").gsub("'", "'\\\\''")}'"
      end
    end

    def container_id_for(container_name:, only_running: false)
      docker :container, :ls, *("--all" unless only_running), "--filter", "name=^#{container_name}$", "--quiet"
    end

    def make_directory_for(remote_file)
      make_directory Pathname.new(remote_file).dirname.to_s
    end

    def make_directory(path)
      [ :mkdir, "-p", path ]
    end

    def remove_directory(path)
      [ :rm, "-r", path ]
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

      def any(*commands)
        combine *commands, by: "||"
      end

      def xargs(command)
        [ :xargs, command ].flatten
      end

      def shell(command)
        [ :sh, "-c", "'#{command.flatten.join(" ").gsub("'", "'\\\\''")}'" ]
      end

      def docker(*args)
        args.compact.unshift :docker
      end

      def git(*args, path: nil)
        [ :git, *([ "-C", path ] if path), *args.compact ]
      end

      def tags(**details)
        Kamal::Tags.from_config(config, **details)
      end
  end
end
