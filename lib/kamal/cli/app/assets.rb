class Kamal::Cli::App::Assets
  include Kamal::Cli::App::CounterpartVersion

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
      execute *app.sync_asset_volumes(other_versions: other_versions)
    end
  end

  private
    def other_versions
      current_version = capture_with_info(*app.current_running_version, raise_on_non_zero_exit: false).strip.presence
      [ *current_version, *counterpart_versions ]
    end

    def app
      @app ||= KAMAL.app(role: role, host: host)
    end
end
