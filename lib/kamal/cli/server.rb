class Kamal::Cli::Server < Kamal::Cli::Base
  desc "exec", "Run a custom command on the server (use --help to show options)"
  option :interactive, type: :boolean, aliases: "-i", default: false, desc: "Run the command interactively (use for console/bash)"
  def exec(*cmd)
    cmd = Kamal::Utils.join_commands(cmd)
    hosts = KAMAL.hosts | KAMAL.accessory_hosts

    case
    when options[:interactive]
      host = KAMAL.primary_host

      say "Running '#{cmd}' on #{host} interactively...", :magenta

      run_locally { exec KAMAL.server.run_over_ssh(cmd, host: host) }
    else
      say "Running '#{cmd}' on #{hosts.join(', ')}...", :magenta

      on(hosts) do |host|
        execute *KAMAL.auditor.record("Executed cmd '#{cmd}' on #{host}"), verbosity: :debug
        puts_by_host host, capture_with_info(cmd)
      end
    end
  end

  desc "bootstrap", "Set up Docker to run Kamal apps"
  def bootstrap
    with_lock do
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
      end

      if missing.any?
        raise "Docker is not installed on #{missing.join(", ")} and can't be automatically installed without having root access and either `wget` or `curl`. Install Docker manually: https://docs.docker.com/engine/install/"
      end

      run_hook "docker-setup"
    end
  end
end
