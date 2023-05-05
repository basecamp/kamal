class Mrsk::Cli::Healthcheck < Mrsk::Cli::Base
  default_command :perform

  desc "perform", "Health check current app version"
  def perform
    on(MRSK.primary_host) do
      begin
        execute *MRSK.healthcheck.run
        Mrsk::Utils::HealthcheckPoller.wait_for_healthy { capture_with_info(*MRSK.healthcheck.status) }
      rescue Mrsk::Utils::HealthcheckPoller::HealthcheckError => e
        error capture_with_info(*MRSK.healthcheck.logs)
        error capture_with_pretty_json(*MRSK.healthcheck.container_health_log)
        raise
      ensure
        execute *MRSK.healthcheck.stop, raise_on_non_zero_exit: false
        execute *MRSK.healthcheck.remove, raise_on_non_zero_exit: false
      end
    end
  end
end
