class Kamal::Cli::Healthcheck < Kamal::Cli::Base
  default_command :perform

  desc "perform", "Health check current app version"
  def perform
    on(KAMAL.primary_host) do
      begin
        execute *KAMAL.healthcheck.run
        Kamal::Utils::HealthcheckPoller.wait_for_healthy { capture_with_info(*KAMAL.healthcheck.status) }
      rescue Kamal::Utils::HealthcheckPoller::HealthcheckError => e
        error capture_with_info(*KAMAL.healthcheck.logs)
        error capture_with_pretty_json(*KAMAL.healthcheck.container_health_log)
        raise
      ensure
        execute *KAMAL.healthcheck.stop, raise_on_non_zero_exit: false
        execute *KAMAL.healthcheck.remove, raise_on_non_zero_exit: false
      end
    end
  end
end
