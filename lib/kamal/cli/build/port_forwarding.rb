require "open3"
require "timeout"

class Kamal::Cli::Build::PortForwarding
  READY_TOKEN = "kamal-port-forward-ready"
  READY_TIMEOUT = 30
  TEARDOWN_GRACE = 5

  attr_reader :hosts, :port, :ssh_options

  def initialize(hosts, port, **ssh_options)
    @hosts = hosts
    @port = port
    @ssh_options = ssh_options

    if Array(ssh_options[:key_data]).any?
      raise "ssh key_data is not supported when forwarding the local registry port; use keys or an ssh agent instead (key_data is deprecated and will be removed in Kamal 3)"
    end
  end

  def forward
    @children = []
    forward_ports

    yield
  ensure
    stop
  end

  private
    # net-ssh's in-process reverse forwarding deadlocks when a large amount of
    # data flows back through the tunnel — e.g. pulling an image with a layer
    # bigger than ~27 MiB from the local registry. The single ssh.loop pump
    # starves while the main thread drives the pull, the forwarded channel's
    # window is exhausted, and the transfer wedges. Carry the tunnel over the
    # OS ssh client instead, which handles bulk transfer reliably. See #1886.
    def forward_ports
      hosts.each { |host| @children << start_forward(host) }

      # The tunnels establish in parallel once spawned, so READY_TIMEOUT is a
      # single deadline shared across all hosts, not a per-host allowance.
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + READY_TIMEOUT
      @children.each { |child| wait_until_ready(child, deadline) }
    end

    def start_forward(host)
      stdin, output, wait_thread = Open3.popen2e(*ssh_command(host))
      { host: host, stdin: stdin, output: output, wait_thread: wait_thread }
    end

    # With ExitOnForwardFailure=yes the remote command only runs once the
    # reverse forward is established, so receiving READY proves the tunnel is up.
    def wait_until_ready(child, deadline)
      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      raise Timeout::Error if remaining <= 0

      Timeout.timeout(remaining) do
        while (line = child[:output].gets)
          return if line.strip == READY_TOKEN
        end

        raise "Failed to establish port forward on #{child[:host]} (ssh exited #{child[:wait_thread].value.exitstatus})"
      end
    rescue Timeout::Error
      raise "Timed out waiting for port forwarding to be established on #{child[:host]}"
    end

    def stop
      Array(@children).each do |child|
        close_io child[:stdin]
        terminate child[:wait_thread]
        close_io child[:output]
      end

      @children = []
    end

    def close_io(io)
      io.close unless io.closed?
    rescue IOError
      # already closed
    end

    # Closing stdin sends EOF to the remote `cat`, so ssh usually exits on its
    # own; TERM then KILL are a backstop.
    def terminate(wait_thread)
      Process.kill "TERM", wait_thread.pid
      return if wait_thread.join(TEARDOWN_GRACE)

      Process.kill "KILL", wait_thread.pid
      wait_thread.join(TEARDOWN_GRACE)
    rescue Errno::ESRCH, Errno::EPERM
      # process already gone
    end

    def ssh_command(host)
      [
        "ssh", "-T",
        "-o", "ExitOnForwardFailure=yes",
        # BatchMode fails fast instead of prompting — a background tunnel can't
        # service prompts. accept-new keeps net-ssh's default host key policy:
        # accept unknown keys, reject changed ones.
        "-o", "BatchMode=yes",
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ServerAliveInterval=#{ssh_options[:keepalive_interval] || 15}",
        "-o", "ServerAliveCountMax=4",
        *port_option,
        *key_options,
        *config_option,
        *proxy_option,
        "-R", "127.0.0.1:#{port}:localhost:#{port}",
        destination(host),
        "echo #{READY_TOKEN} && exec cat"
      ]
    end

    def destination(host)
      ssh_options[:user] ? "#{ssh_options[:user]}@#{host}" : host.to_s
    end

    def port_option
      ssh_options[:port] ? [ "-p", ssh_options[:port].to_s ] : []
    end

    def key_options
      options = Array(ssh_options[:keys]).flat_map { |key| [ "-i", key.to_s ] }
      options += [ "-o", "IdentitiesOnly=yes" ] if ssh_options[:keys_only]
      options += [ "-o", "ForwardAgent=yes" ] if ssh_options[:forward_agent]
      options
    end

    def config_option
      case (config = ssh_options[:config])
      when nil, true
        [] # ssh reads its default config files, matching net-ssh's default
      when false
        [ "-F", "/dev/null" ] # ignore all config files
      else
        config_file_option Array(config)
      end
    end

    def config_file_option(paths)
      # OpenSSH honors only the last -F flag, so multiple config files can't
      # be passed through faithfully.
      if paths.size > 1
        raise "Multiple ssh config files (#{paths.join(", ")}) are not supported when forwarding the local registry port; combine them into one file, e.g. with Include"
      end

      [ "-F", (paths.first || "/dev/null").to_s ]
    end

    def proxy_option
      case (proxy = ssh_options[:proxy])
      when Net::SSH::Proxy::Jump
        [ "-J", proxy.jump_proxies ]
      when Net::SSH::Proxy::Command
        [ "-o", "ProxyCommand=#{proxy.command_line_template}" ]
      else
        []
      end
    end
end
