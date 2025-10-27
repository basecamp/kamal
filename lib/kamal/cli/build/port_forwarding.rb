require "concurrent/atomic/count_down_latch"

class Kamal::Cli::Build::PortForwarding
  attr_reader :hosts, :port, :ssh_options

  def initialize(hosts, port, **ssh_options)
    @hosts = hosts
    @port = port
    @ssh_options = ssh_options
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
          begin
            Net::SSH.start(host, ssh_options[:user], **ssh_options.except(:user)) do |ssh|
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
          rescue Exception => e
            error "Error setting up port forwarding to #{host}: #{e.class}: #{e.message}"
            error e.backtrace.join("\n")

            raise
          end
        end
      end

      raise "Timed out waiting for port forwarding to be established" unless ready.wait(30)
    end

    def error(message)
      SSHKit.config.output.error(message)
    end
end
