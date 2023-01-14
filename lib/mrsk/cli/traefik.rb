require "mrsk/cli/base"

class Mrsk::Cli::Traefik < Mrsk::Cli::Base
  desc "boot", "Boot Traefik on servers"
  def boot
    on(MRSK.config.role(:web).hosts) { execute *MRSK.traefik.run, raise_on_non_zero_exit: false }
  end

  desc "start", "Start existing Traefik on servers"
  def start
    on(MRSK.config.role(:web).hosts) { execute *MRSK.traefik.start, raise_on_non_zero_exit: false }
  end

  desc "stop", "Stop Traefik on servers"
  def stop
    on(MRSK.config.role(:web).hosts) { execute *MRSK.traefik.stop, raise_on_non_zero_exit: false }
  end

  desc "restart", "Restart Traefik on servers"
  def restart
    invoke :stop
    invoke :start
  end

  desc "details", "Display details about Traefik containers from servers"
  def details
    on(MRSK.config.role(:web).hosts) { |host| puts "Traefik Host: #{host}\n" + capture(*MRSK.traefik.info, verbosity: Logger::INFO) + "\n\n" }
  end

  desc "logs", "Show last 100 log lines from Traefik on servers"
  def logs
    on(MRSK.config.hosts) { |host| puts "Traefik Host: #{host}\n" + capture(*MRSK.traefik.logs) + "\n\n" }
  end

  desc "remove", "Remove Traefik container and image from servers"
  def remove
    invoke :stop

    on(MRSK.config.role(:web).hosts) do
      execute *MRSK.traefik.remove_container
      execute *MRSK.traefik.remove_image
    end
  end
end
