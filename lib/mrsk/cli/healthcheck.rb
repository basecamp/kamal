class Mrsk::Cli::Healthcheck < Mrsk::Cli::Base
  default_command :perform

  desc "perform", "Health check current app version"
  def perform
    on(MRSK.primary_host) do
      begin
        execute *MRSK.healthcheck.run

        target = "Health check against #{MRSK.config.healthcheck["path"]}"

        if capture_with_info(*MRSK.healthcheck.curl) == "200"
          info "#{target} succeeded with 200 OK!"
        else
          # Catches 1xx, 2xx, 3xx
          raise SSHKit::Command::Failed, "#{target} failed to return 200 OK!"
        end
      rescue SSHKit::Command::Failed => e
        error capture_with_info(*MRSK.healthcheck.logs)

        if e.message =~ /curl/
          # Catches 4xx, 5xx
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
