module Kamal::Cli::Healthcheck::Poller
  extend self

  def wait_for_healthy(role, &block)
    attempt = 1
    timeout_at = Time.now + KAMAL.config.deploy_timeout
    readiness_delay = KAMAL.config.readiness_delay

    begin
      status = block.call

      if status == "running"
        # Wait for the readiness delay and confirm it is still running
        if readiness_delay > 0
          info "Container is running, waiting for readiness delay of #{readiness_delay} seconds"
          sleep readiness_delay
          status = block.call
        end
      end

      unless %w[ running healthy ].include?(status)
        raise Kamal::Cli::Healthcheck::Error, "container not ready after #{KAMAL.config.deploy_timeout} seconds (#{status})"
      end
    rescue Kamal::Cli::Healthcheck::Error => e
      time_left = timeout_at - Time.now
      if time_left > 0
        sleep [ attempt, time_left ].min
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
