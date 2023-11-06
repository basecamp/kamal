class Kamal::Cli::Server < Kamal::Cli::Base
  desc "bootstrap", "Set up Docker to run Kamal apps"
  def bootstrap
    missing_curl = []
    missing_docker = []

    on(KAMAL.hosts | KAMAL.accessory_hosts) do |host|

      unless (execute(*KAMAL.curl.installed?, raise_on_non_zero_exit: false) && execute(*KAMAL.curl.is_installable_with_apt?, raise_on_non_zero_exit: false))
        if execute(execute *KAMAL.curl.install, raise_on_non_zero_exit: false)
          info "Missing CURL on #{host}. Installing…"
          execute *KAMAL.curl.install
        else
          missing_curl << host
        end
      end

      unless (!missing_curl.include(host) && execute(*KAMAL.docker.installed?, raise_on_non_zero_exit: false))
        if execute(*KAMAL.docker.superuser?, raise_on_non_zero_exit: false)
          info "Missing Docker on #{host}. Installing…"
          execute *KAMAL.docker.install
        else
          missing_docker << host
        end
      end

      execute(*KAMAL.server.ensure_run_directory)
    end

    if missing_curl.any?
      raise "Curl is not installed on #{missing.join(", ")} and can't be automatically installed. Please, install curl manually and run 'kamal setup'."
    end

    if missing_docker.any?
      raise "Docker is not installed on #{missing.join(", ")} and can't be automatically installed without having root access and the `curl` command available. Install Docker manually: https://docs.docker.com/engine/install/"
    end
  end
end
