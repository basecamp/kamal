module Kamal::Cli::Healthcheck::Poller
  extend self

  def wait_for_healthy(pause_after_ready: false, &block)
    attempt = 1
    max_attempts = 7

    begin
      case status = block.call
      when "healthy"
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

  private
    def info(message)
      SSHKit.config.output.info(message)
    end
end
