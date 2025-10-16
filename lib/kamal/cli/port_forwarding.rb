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
    @threads = hosts.map do |host|
      Thread.new do
        Net::SSH.start(host, KAMAL.config.ssh.user, **{ proxy: KAMAL.config.ssh.proxy }.compact) do |ssh|
          ssh.forward.remote(port, "localhost", port, "localhost")
          ssh.loop(0.1) do
            if @done
              ssh.forward.cancel_remote(port, "localhost")
              break
            else
              true
            end
          end
        end
      end
    end
  end
end
