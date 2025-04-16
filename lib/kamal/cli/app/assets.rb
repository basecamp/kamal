class Kamal::Cli::App::Assets
  attr_reader :host, :role, :sshkit
  delegate :execute, :capture_with_info, :info, to: :sshkit
  delegate :assets?, to: :role

  def initialize(host, role, sshkit)
    @host = host
    @role = role
    @sshkit = sshkit
  end

  def run
    if assets?
      execute *app.extract_assets
      old_version = capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip
      execute *app.sync_asset_volumes(old_version: old_version)
    end
  end

  private
    def app
      @app ||= KAMAL.app(role: role, host: host)
    end
end
