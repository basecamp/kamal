class Kamal::Cli::Server < Kamal::Cli::Base
  desc "exec", "Run a custom command on the server (use --help to show options)"
  option :interactive, type: :boolean, aliases: "-i", default: false, desc: "Run the command interactively (use for console/bash)"
  option :raw, type: :boolean, default: false, desc: "Output raw, unmodified stdout"
  def exec(*cmd)
    raw = options[:raw]

    if raw && options[:interactive]
      raise ArgumentError, "Raw is not compatible with interactive"
    end

    with_raw_output(raw) do
      pre_connect_if_required

      cmd = Kamal::Utils.join_commands(cmd)
      hosts = KAMAL.hosts
      quiet = options[:quiet]

      case
      when options[:interactive]
        host = KAMAL.primary_host

        say "Running '#{cmd}' on #{host} interactively...", :magenta

        run_locally { exec KAMAL.server.run_over_ssh(cmd, host: host) }
      else
        say "Running '#{cmd}' on #{hosts.join(', ')}...", :magenta

        on(hosts) do |host|
          execute *KAMAL.auditor.record("Executed cmd '#{cmd}' on #{host}"), verbosity: :debug
          puts_by_host host, capture_with_info(cmd, strip: !raw), quiet: quiet, raw: raw
        end
      end
    end
  end

  desc "bootstrap", "Set up Docker to run Kamal apps"
  def bootstrap
    modify(lock: true) do
      missing = []
      engine = KAMAL.config.container_engine

      on(KAMAL.hosts) do |host|
        unless execute(*KAMAL.docker.installed?, raise_on_non_zero_exit: false)
          # Only Docker can be auto-installed via a universal script; Podman is distro-specific.
          if engine == :docker && execute(*KAMAL.docker.superuser?, raise_on_non_zero_exit: false)
            info "Missing Docker on #{host}. Installing…"
            execute *KAMAL.docker.install

            unless execute(*KAMAL.docker.root?, raise_on_non_zero_exit: false) ||
                   execute(*KAMAL.docker.in_docker_group?, raise_on_non_zero_exit: false)
              execute *KAMAL.docker.add_to_docker_group
              begin
                execute *KAMAL.docker.refresh_session
              rescue IOError
                info "Session refreshed due to group change."
              end
            end
          else
            missing << host
          end
        end
      end

      if missing.any?
        if engine == :docker
          raise "Docker is not installed on #{missing.join(", ")} and can't be automatically installed without having root access and either `wget` or `curl`. Install Docker manually: https://docs.docker.com/engine/install/"
        else
          raise "Podman is not installed on #{missing.join(", ")}. Kamal can't install Podman automatically; install it manually: https://podman.io/docs/installation"
        end
      end

      if engine == :podman
        # Rootless Podman survives reboot via linger + the user restart service — the
        # analog of the Docker daemon starting at boot and restarting containers.
        on(KAMAL.hosts) do |host|
          if execute(*KAMAL.docker.rootless?, raise_on_non_zero_exit: false)
            info "Enabling rootless Podman boot survival on #{host}…"
            execute *KAMAL.docker.enable_linger, raise_on_non_zero_exit: false
            execute *KAMAL.docker.enable_podman_restart, raise_on_non_zero_exit: false
          end
        end
      end

      run_hook "docker-setup"
    end
  end
end
