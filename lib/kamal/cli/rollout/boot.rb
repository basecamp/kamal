class Kamal::Cli::Rollout::Boot
  include Kamal::Cli::App::CounterpartVersion

  attr_reader :host, :role, :version, :sshkit
  delegate :execute, :capture_with_info, :info, :error, :upload!, to: :sshkit
  delegate :assets?, :running_proxy?, to: :role

  def initialize(host, role, sshkit, version)
    @host = host
    @role = role
    @version = version
    @sshkit = sshkit
  end

  def run
    old_version = old_version_renamed_if_clashing

    begin
      start_new_version
    rescue => e
      stop_new_version
      raise
    end

    stop_old_version(old_version) if old_version
  end

  private
    def old_version_renamed_if_clashing
      if capture_with_info(*app.container_id_for_version(version), raise_on_non_zero_exit: false).present?
        renamed_version = "#{version}_replaced_#{SecureRandom.hex(8)}"
        info "Renaming rollout container #{version} to #{renamed_version} as already deployed on #{host}"
        audit("Renaming rollout container #{version} to #{renamed_version}")
        execute *app.rename_container(version: version, new_version: renamed_version)
      end

      capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip.presence
    end

    def start_new_version
      audit "Booted rollout #{role} version #{version}"
      hostname = "#{host.to_s[0...51].chomp(".")}-#{SecureRandom.hex(6)}"

      execute *app.ensure_env_directory
      upload! role.secrets_io(host), role.secrets_path, mode: "0600"

      execute *app.run(hostname: hostname)

      if running_proxy?
        endpoint = capture_with_info(*app.container_id_for_version(version)).strip
        raise Kamal::Cli::BootError, "Failed to get endpoint for rollout #{role} on #{host}, did the container boot?" if endpoint.empty?
        execute *app.rollout_deploy(target: endpoint)
      else
        Kamal::Cli::Healthcheck::Poller.wait_for_healthy { capture_with_info(*app.status(version: version)) }
      end
    rescue => e
      error "Failed to boot rollout #{role} on #{host}"
      raise e
    end

    def stop_new_version
      execute *app.stop(version: version), raise_on_non_zero_exit: false
    end

    def stop_old_version(version)
      execute *app.stop(version: version), raise_on_non_zero_exit: false
      execute *app.clean_up_assets(keep_versions: counterpart_versions) if assets?
    end

    def app
      @app ||= KAMAL.app(role: role, host: host)
    end

    def auditor
      @auditor ||= KAMAL.auditor(role: role)
    end

    def audit(message)
      execute *auditor.record(message), verbosity: :debug
    end
end
