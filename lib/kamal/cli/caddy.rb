class Kamal::Cli::Caddy < Kamal::Cli::Base
  desc "boot", "Boot Caddy on servers"
  def boot
    with_lock do
      on(KAMAL.hosts) do |host|
        execute *KAMAL.docker.create_network
      rescue SSHKit::Command::Failed => e
        raise unless e.message.include?("already exists")
      end

      on(KAMAL.proxy_hosts) do |host|
        execute *KAMAL.registry.login

        # version = capture_with_info(*KAMAL.caddy.version).strip.presence
        execute *KAMAL.caddy.start_or_run
      end
    end
  end

  desc "remove", "Remove caddy container and image from servers"
  option :force, type: :boolean, default: false, desc: "Force removing caddy when apps are still installed"
  def remove
    with_lock do
      KAMAL.caddy.stop
      KAMAL.caddy.remove_container
      KAMAL.caddy.remove_image
      KAMAL.caddy.remove_caddy_directory
    end
  end
end
