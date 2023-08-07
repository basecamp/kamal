require "sshkit"
require "sshkit/dsl"
require "active_support/core_ext/hash/deep_merge"
require "json"

class SSHKit::Backend::Abstract
  def capture_with_info(*args, **kwargs)
    capture(*args, **kwargs, verbosity: Logger::INFO)
  end

  def capture_with_debug(*args, **kwargs)
    capture(*args, **kwargs, verbosity: Logger::DEBUG)
  end

  def capture_with_pretty_json(*args, **kwargs)
    JSON.pretty_generate(JSON.parse(capture(*args, **kwargs)))
  end

  def puts_by_host(host, output, type: "App")
    puts "#{type} Host: #{host}\n#{output}\n\n"
  end

  # Our execution pattern is for the CLI execute args lists returned
  # from commands, but this doesn't support returning execution options
  # from the command.
  #
  # Support this by using kwargs for CLI options and merging with the
  # args-extracted options.
  module CommandEnvMerge
    private

    # Override to merge options returned by commands in the args list with
    # options passed by the CLI and pass them along as kwargs.
    def command(args, options)
      more_options, args = args.partition { |a| a.is_a? Hash }
      more_options << options

      build_command(args, **more_options.reduce(:deep_merge))
    end

    # Destructure options to pluck out env for merge
    def build_command(args, env: nil, **options)
      # Rely on native Ruby kwargs precedence rather than explicit Hash merges
      SSHKit::Command.new(*args, **default_command_options, **options, env: env_for(env))
    end

    def default_command_options
      { in: pwd_path, host: @host, user: @user, group: @group }
    end

    def env_for(env)
      @env.to_h.merge(env.to_h)
    end
  end
  prepend CommandEnvMerge
end

class SSHKit::Backend::Netssh::Configuration
  attr_accessor :max_concurrent_starts
end

class SSHKit::Backend::Netssh
  module LimitConcurrentStartsClass
    attr_reader :start_semaphore

    def configure(&block)
      super &block
      # Create this here to avoid lazy creation by multiple threads
      if config.max_concurrent_starts
        @start_semaphore = Concurrent::Semaphore.new(config.max_concurrent_starts)
      end
    end
  end

  class << self
    prepend LimitConcurrentStartsClass
  end

  module LimitConcurrentStartsInstance
    private
      def with_ssh(&block)
        host.ssh_options = self.class.config.ssh_options.merge(host.ssh_options || {})
        self.class.pool.with(
          method(:start_with_concurrency_limit),
          String(host.hostname),
          host.username,
          host.netssh_options,
          &block
        )
      end

      def start_with_concurrency_limit(*args)
        if self.class.start_semaphore
          self.class.start_semaphore.acquire do
            Net::SSH.start(*args)
          end
        else
          Net::SSH.start(*args)
        end
      end
  end

  prepend LimitConcurrentStartsInstance
end
