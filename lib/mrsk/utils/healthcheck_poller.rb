class Mrsk::Utils::HealthcheckPoller
  TRAEFIK_HEALTHY_DELAY = 2

  class HealthcheckError < StandardError; end

  class << self
    def wait_for_healthy(pause_after_ready: false, &block)
      attempt = 1
      max_attempts = MRSK.config.healthcheck["max_attempts"]
      initial_delay = MRSK.config.healthcheck["initial_delay"]

      if initial_delay > 0
        info "Waiting #{initial_delay}s before checking container health..."
        sleep initial_delay
      end

      begin
        case status = block.call
        when "healthy"
          sleep TRAEFIK_HEALTHY_DELAY if pause_after_ready
        when "running" # No health check configured
          sleep MRSK.config.readiness_delay if pause_after_ready
        else
          raise HealthcheckError, "container not ready (#{status})"
        end
      rescue HealthcheckError => e
        if attempt <= max_attempts
          info "#{e.message}, retrying in #{attempt}s (attempt #{attempt}/#{max_attempts})..."
          sleep attempt
          attempt += 1
          retry
        else
          raise
        end
      end

      info "Container is healthy!"
    end

    private
      def info(message)
        SSHKit.config.output.info(message)
      end
  end
end
