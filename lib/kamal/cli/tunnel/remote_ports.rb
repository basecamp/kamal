Signal.trap "SIGPROF" do
  Thread.list.each do |thread|
    puts thread.name
    puts thread.backtrace.map { |bt| "  #{bt}" }
    puts
  end
end

require "concurrent/map"

class Kamal::Cli::Tunnel::RemotePorts
  attr_reader :hosts, :port

  def initialize(hosts, port)
    @hosts = hosts
    @port = port
    @open = false
  end

  def open
    @open = true
    @opened = Concurrent::Map.new

    @threads = hosts.map do |host|
      Thread.new do
        Net::SSH.start(host, KAMAL.config.ssh.user) do |ssh|
          forwarding = nil
          ssh.forward.remote(port, "localhost", port, "localhost") do |actual_remote_port|
            forwarding = !!actual_remote_port
            :no_exception # will yield the exception on my own thread
          end
          ssh.loop { forwarding.nil? }
          if forwarding
            @opened[host] = true
            ssh.loop(0.1) { @open }

            ssh.forward.cancel_remote(port, "localhost")
            ssh.loop(0.1) { ssh.forward.active_remotes.include?([ port, "localhost" ]) }
          else
            @opened[host] = false
          end
        end
      rescue => e
        @opened[host] = false

        puts e.message
        puts e.backtrace
      end
    end

    loop do
      break if @opened.size == hosts.size
      sleep 0.1
    end

    raise "Could not open tunnels on #{opened.reject { |k, v| v }.join(", ")}" unless @opened.values.all?
  end

  def close
    p "Closing"
    @open = false
    p "Joining"
    @threads.each(&:join)
    p "Joined"
  end
end
