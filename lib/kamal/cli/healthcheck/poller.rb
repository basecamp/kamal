module Kamal::Cli::Healthcheck::Poller
  extend self

  TRAEFIK_UPDATE_DELAY = 5


  def wait_for_healthy(pause_after_ready: false, &block)
    attempt = 1
    max_attempts = KAMAL.config.healthcheck.max_attempts

    begin
      case status = block.call
      when "healthy"
        sleep TRAEFIK_UPDATE_DELAY if pause_after_ready
      when "running" # No health check configured
        sleep KAMAL.config.readiness_delay if pause_after_ready
      else
        raise Kamal::Cli::Healthcheck::Error, "container not ready (#{status})"
      end
    rescue Kamal::Cli::Healthcheck::Error => e
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

  def wait_for_unhealthy(pause_after_ready: false, &block)
    attempt = 1
    max_attempts = KAMAL.config.healthcheck.max_attempts

    begin
      case status = block.call
      when "unhealthy"
        sleep TRAEFIK_UPDATE_DELAY if pause_after_ready
      else
        raise Kamal::Cli::Healthcheck::Error, "container not unhealthy (#{status})"
      end
    rescue Kamal::Cli::Healthcheck::Error => e
      if attempt <= max_attempts
        info "#{e.message}, retrying in #{attempt}s (attempt #{attempt}/#{max_attempts})..."
        sleep attempt
        attempt += 1
        retry
      else
        raise
      end
    end

    info "Container is unhealthy!"
  end

  private
    def info(message)
      SSHKit.config.output.info(message)
    end
end
