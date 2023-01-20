require "mrsk/cli/base"

class Mrsk::Cli::Traefik < Mrsk::Cli::Base
  desc "boot", "Boot Traefik on servers"
  def boot
    on(MRSK.config.traefik_hosts) { execute *MRSK.traefik.run, raise_on_non_zero_exit: false }
  end

  desc "start", "Start existing Traefik on servers"
  def start
    on(MRSK.config.traefik_hosts) { execute *MRSK.traefik.start, raise_on_non_zero_exit: false }
  end

  desc "stop", "Stop Traefik on servers"
  def stop
    on(MRSK.config.traefik_hosts) { execute *MRSK.traefik.stop, raise_on_non_zero_exit: false }
  end

  desc "restart", "Restart Traefik on servers"
  def restart
    invoke :stop
    invoke :start
  end

  desc "details", "Display details about Traefik containers from servers"
  def details
    on(MRSK.config.traefik_hosts) { |host| puts_by_host host, capture_with_info(*MRSK.traefik.info), type: "Traefik" }
  end

  desc "logs", "Show last 100 log lines from Traefik on servers"
  def logs
    on(MRSK.config.hosts) { |host| puts_by_host host, capture(*MRSK.traefik.logs), type: "Traefik" }
  end

  desc "remove", "Remove Traefik container and image from servers"
  def remove
    invoke :stop

    on(MRSK.config.traefik_hosts) do
      execute *MRSK.traefik.remove_container
      execute *MRSK.traefik.remove_image
    end
  end
end
