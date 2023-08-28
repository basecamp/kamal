class Kamal::Utils::HealthcheckPoller
  TRAEFIK_HEALTHY_DELAY = 2

  class HealthcheckError < StandardError; end

  class << self
    def wait_for_healthy(pause_after_ready: false, &block)
      Kamal::Utils.poll(max_attempts: KAMAL.config.healthcheck["max_attempts"], exception: HealthcheckError) do
        case status = block.call
        when "healthy"
          sleep TRAEFIK_HEALTHY_DELAY if pause_after_ready
        when "running" # No health check configured
          sleep KAMAL.config.readiness_delay if pause_after_ready
        else
          raise HealthcheckError, "container not ready (#{status})"
        end

        SSHKit.config.output.info "Container is healthy!"
      end
    end
  end
end
