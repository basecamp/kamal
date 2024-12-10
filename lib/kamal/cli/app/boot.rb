class Kamal::Cli::App::Boot
  attr_reader :host, :role, :version, :barrier, :sshkit
  delegate :execute, :capture_with_info, :capture_with_pretty_json, :info, :error, :upload!, to: :sshkit
  delegate :assets?, :running_proxy?, to: :role

  def initialize(host, role, sshkit, version, barrier)
    @host = host
    @role = role
    @version = version
    @barrier = barrier
    @sshkit = sshkit
  end

  def run
    old_version = old_version_renamed_if_clashing

    wait_at_barrier if queuer?

    begin
      start_new_version
    rescue => e
      close_barrier if gatekeeper?
      stop_new_version
      raise
    end

    release_barrier if gatekeeper?

    if old_version
      stop_old_version(old_version)
    end
  end

  private
    def old_version_renamed_if_clashing
      if capture_with_info(*app.container_id_for_version(version), raise_on_non_zero_exit: false).present?
        renamed_version = "#{version}_replaced_#{SecureRandom.hex(8)}"
        info "Renaming container #{version} to #{renamed_version} as already deployed on #{host}"
        audit("Renaming container #{version} to #{renamed_version}")
        execute *app.rename_container(version: version, new_version: renamed_version)
      end

      capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip.presence
    end

    def start_new_version
      audit "Booted app version #{version}"
      hostname = "#{host.to_s[0...51].chomp(".")}-#{SecureRandom.hex(6)}"

      execute *app.ensure_env_directory
      upload! role.secrets_io(host), role.secrets_path, mode: "0600"

      execute *app.run(hostname: hostname)
      if running_proxy?
        endpoint = capture_with_info(*app.container_id_for_version(version)).strip
        raise Kamal::Cli::BootError, "Failed to get endpoint for #{role} on #{host}, did the container boot?" if endpoint.empty?
        execute *app.deploy(target: endpoint)
      else
        Kamal::Cli::Healthcheck::Poller.wait_for_healthy(pause_after_ready: true) { capture_with_info(*app.status(version: version)) }
      end
    rescue => e
      error "Failed to boot #{role} on #{host}"
      raise e
    end

    def stop_new_version
      execute *app.stop(version: version), raise_on_non_zero_exit: false
    end

    def stop_old_version(version)
      execute *app.stop(version: version), raise_on_non_zero_exit: false
      execute *app.clean_up_assets if assets?
    end

    def release_barrier
      if barrier.open
        info "First #{KAMAL.primary_role} container is healthy on #{host}, booting any other roles"
      end
    end

    def wait_at_barrier
      info "Waiting for the first healthy #{KAMAL.primary_role} container before booting #{role} on #{host}..."
      barrier.wait
      info "First #{KAMAL.primary_role} container is healthy, booting #{role} on #{host}..."
    rescue Kamal::Cli::Healthcheck::Error
      info "First #{KAMAL.primary_role} container is unhealthy, not booting #{role} on #{host}"
      raise
    end

    def close_barrier
      if barrier.close
        info "First #{KAMAL.primary_role} container is unhealthy on #{host}, not booting any other roles"
        begin
          error capture_with_info(*app.logs(container_id: app.container_id_for_version(version)))
          error capture_with_info(*app.container_health_log(version: version))
        rescue SSHKit::Command::Failed
          error "Could not fetch logs for #{version}"
        end
      end
    end

    def barrier_role?
      role == KAMAL.primary_role
    end

    def app
      @app ||= KAMAL.app(role: role, host: host)
    end

    def auditor
      @auditor = KAMAL.auditor(role: role)
    end

    def audit(message)
      execute *auditor.record(message), verbosity: :debug
    end

    def gatekeeper?
      barrier && barrier_role?
    end

    def queuer?
      barrier && !barrier_role?
    end
end
