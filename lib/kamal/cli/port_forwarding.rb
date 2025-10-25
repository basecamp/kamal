require "concurrent/atomic/count_down_latch"

class Kamal::Cli::PortForwarding
  attr_reader :hosts, :port

  def initialize(hosts, port)
    @hosts = hosts
    @port = port
  end

  def forward
    @done = false
    forward_ports

    yield
  ensure
    stop
  end

  private

  def stop
    @done = true
    @threads.to_a.each(&:join)
  end

  def forward_ports
    ready = Concurrent::CountDownLatch.new(hosts.size)

    @threads = hosts.map do |host|
      Thread.new do
        Net::SSH.start(host, KAMAL.config.ssh.user, **{ proxy: KAMAL.config.ssh.proxy }.compact) do |ssh|
          ssh.forward.remote(port, "localhost", port, "127.0.0.1") do |remote_port, bind_address|
            if remote_port == :error
              raise "Failed to establish port forward on #{host}"
            else
              ready.count_down
            end
          end

          ssh.loop(0.1) do
            if @done
              ssh.forward.cancel_remote(port, "127.0.0.1")
              break
            else
              true
            end
          end
        end
      end
    end

    raise "Timed out waiting for port forwarding to be established" unless ready.wait(10)
  end
end
