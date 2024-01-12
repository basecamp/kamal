class Kamal::Cli::Server < Kamal::Cli::Base
  desc "exec", "Run a command on the server"
  def exec(cmd)
    hosts = KAMAL.hosts | KAMAL.accessory_hosts

    say "Running '#{cmd}' on #{hosts.join(', ')}...", :magenta

    on(hosts) do |host|
      execute *KAMAL.auditor.record("Executed cmd '#{cmd}' on #{host}"), verbosity: :debug
      puts_by_host host, capture_with_info(cmd)
    end
  end

  desc "bootstrap", "Set up Docker to run Kamal apps"
  def bootstrap
    missing = []

    on(KAMAL.hosts | KAMAL.accessory_hosts) do |host|
      unless execute(*KAMAL.docker.installed?, raise_on_non_zero_exit: false)
        if execute(*KAMAL.docker.superuser?, raise_on_non_zero_exit: false)
          info "Missing Docker on #{host}. Installing…"
          execute *KAMAL.docker.install
        else
          missing << host
        end
      end

      execute(*KAMAL.server.ensure_run_directory)
    end

    if missing.any?
      raise "Docker is not installed on #{missing.join(", ")} and can't be automatically installed without having root access and the `curl` command available. Install Docker manually: https://docs.docker.com/engine/install/"
    end
  end
end
