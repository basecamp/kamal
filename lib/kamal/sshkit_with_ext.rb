require "sshkit"
require "sshkit/dsl"
require "net/scp"
require "active_support/core_ext/hash/deep_merge"
require "json"
require "resolv"
require "concurrent/atomic/semaphore"

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

  def puts_by_host(host, output, type: "App", quiet: false)
    unless quiet
      puts "#{type} Host: #{host}"
    end
    puts "#{output}\n\n"
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
  attr_accessor :max_concurrent_starts, :dns_retries
end

class SSHKit::Backend::Netssh
  module DnsRetriable
    DNS_RETRY_BASE = 0.1
    DNS_RETRY_MAX = 2.0
    DNS_RETRY_JITTER = 0.1
    DNS_ERROR_MESSAGE = /getaddrinfo|Temporary failure in name resolution|Name or service not known|nodename nor servname provided|No address associated|failed to look up|resolve/i

    def with_dns_retry(hostname, retries: config.dns_retries, base: DNS_RETRY_BASE, max_sleep: DNS_RETRY_MAX, jitter: DNS_RETRY_JITTER)
      attempts = 0
      begin
        attempts += 1
        yield
      rescue => error
        raise unless retryable_dns_error?(error) && attempts <= retries

        delay = dns_retry_sleep(attempts, base: base, jitter: jitter, max_sleep: max_sleep)
        SSHKit.config.output.warn("Retrying DNS for #{hostname} (attempt #{attempts}/#{retries}) in #{format("%0.2f", delay)}s: #{error.message}")
        sleep delay
        retry
      end
    end

    private
      def retryable_dns_error?(error)
        case error
        when Resolv::ResolvError, Resolv::ResolvTimeout
          true
        when SocketError
          error.message =~ DNS_ERROR_MESSAGE
        else
          error.cause && retryable_dns_error?(error.cause)
        end
      end

      def dns_retry_sleep(attempt, base:, jitter:, max_sleep:)
        sleep_for = [ base * (2 ** (attempt - 1)), max_sleep ].min
        sleep_for += Kernel.rand * jitter
        sleep_for
      end
  end

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
    prepend DnsRetriable
  end

  module ConnectSsh
    private
      def connect_ssh(...)
        Net::SSH.start(...)
      end
  end
  include ConnectSsh

  module DnsRetriableConnection
    private
      def connect_ssh(...)
        self.class.with_dns_retry(host.hostname) { super }
      end
  end
  prepend DnsRetriableConnection

  module LimitConcurrentStartsInstance
    private
      def with_ssh(&block)
        host.ssh_options = self.class.config.ssh_options.merge(host.ssh_options || {})
        self.class.pool.with(
          method(:connect_ssh),
          String(host.hostname),
          host.username,
          host.netssh_options,
          &block
        )
      end

      def connect_ssh(...)
        with_concurrency_limit { super }
      end

      def with_concurrency_limit(&block)
        if self.class.start_semaphore
          self.class.start_semaphore.acquire(&block)
        else
          yield
        end
      end
  end
  prepend LimitConcurrentStartsInstance
end

class SSHKit::Runner::Parallel
  # SSHKit joins the threads in sequence and fails on the first error it encounters, which means that we wait threads
  # before the first failure to complete but not for ones after.
  #
  # We'll patch it to wait for them all to complete, and to record all the threads that errored so we can see when a
  # problem occurs on multiple hosts.
  module CompleteAll
    def execute
      threads = hosts.map do |host|
        Thread.new(host) do |h|
          backend(h, &block).run
        rescue ::StandardError => e
          e2 = SSHKit::Runner::ExecuteError.new e
          raise e2, "Exception while executing #{host.user ? "as #{host.user}@" : "on host "}#{host}: #{e.message}"
        end
      end

      exceptions = []
      threads.each do |t|
        begin
          t.join
        rescue SSHKit::Runner::ExecuteError => e
          exceptions << e
        end
      end
      if exceptions.one?
        raise exceptions.first
      elsif exceptions.many?
        raise exceptions.first, [ "Exceptions on #{exceptions.count} hosts:", exceptions.map(&:message) ].join("\n")
      end
    end
  end

  prepend CompleteAll
end

# Avoid net-ssh debug, until https://github.com/net-ssh/net-ssh/pull/953 is merged
module NetSshForwardingNoPuts
  def puts(*)
  end
end

Net::SSH::Service::Forward.prepend NetSshForwardingNoPuts

module SSHKitDslRoles
  # Execute on hosts grouped by role.
  #
  # Unlike `on()` which deduplicates hosts, this allows the same host to have
  # multiple concurrent connections when it appears in multiple roles.
  #
  # Options:
  #   hosts: The hosts to run on (required)
  #   parallel: When true, each role runs in its own thread with separate
  #             connections. When false, hosts run in parallel but roles on each
  #             host run sequentially (default: true)
  #
  # Example:
  #   on_roles(roles) do |host, role|
  #     # deploy role to host
  #   end
  def on_roles(roles, hosts:, parallel: true, &block)
    if parallel
      threads = roles.filter_map do |role|
        if (role_hosts = role.hosts & hosts).any?
          Thread.new do
            on(role_hosts) { |host| instance_exec(host, role, &block) }
          rescue StandardError => e
            raise SSHKit::Runner::ExecuteError.new(e), "Exception while executing on #{role}: #{e.message}"
          end
        end
      end

      exceptions = []
      threads.each do |t|
        begin
          t.join
        rescue SSHKit::Runner::ExecuteError => e
          exceptions << e
        end
      end

      if exceptions.one?
        raise exceptions.first
      elsif exceptions.many?
        raise exceptions.first, [ "Exceptions on #{exceptions.count} roles:", exceptions.map(&:message) ].join("\n")
      end
    else
      # Host-first iteration: hosts run in parallel, roles on each host run sequentially
      on(hosts) do |host|
        roles.each do |role|
          instance_exec(host, role, &block) if role.hosts.include?(host.to_s)
        end
      end
    end
  end
end

SSHKit::DSL.prepend SSHKitDslRoles
