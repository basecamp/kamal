class Mrsk::Cli::Healthcheck < Mrsk::Cli::Base
  DEFAULT_MAX_ATTEMPTS = 7

  class HealthcheckError < StandardError; end

  default_command :perform

  desc "perform", "Health check current app version"
  def perform
    on(MRSK.primary_host) do
      begin
        execute *MRSK.healthcheck.run

        target = "Health check against #{MRSK.config.healthcheck["path"]}"
        attempt = 1
        max_attempts = MRSK.config.healthcheck["max_attempts"] || DEFAULT_MAX_ATTEMPTS

        begin
          status = capture_with_info(*MRSK.healthcheck.curl)

          if status == "200"
            info "#{target} succeeded with 200 OK!"
          else
            raise HealthcheckError, "#{target} failed with status #{status}"
          end
        rescue SSHKit::Command::Failed
          if attempt <= max_attempts
            info "#{target} failed to respond, retrying in #{attempt}s..."
            sleep attempt
            attempt += 1

            retry
          else
            raise
          end
        end
      rescue SSHKit::Command::Failed, HealthcheckError => e
        error capture_with_info(*MRSK.healthcheck.logs)

        if e.message =~ /curl/
          raise SSHKit::Command::Failed, "#{target} failed to return 200 OK!"
        else
          raise
        end
      ensure
        execute *MRSK.healthcheck.stop, raise_on_non_zero_exit: false
        execute *MRSK.healthcheck.remove, raise_on_non_zero_exit: false
      end
    end
  end
end
