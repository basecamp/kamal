class Kamal::Cli::Lock < Kamal::Cli::Base
  desc "status", "Report lock status"
  def status
    handle_missing_lock do
      on(KAMAL.primary_host) do
        puts capture_with_debug(*KAMAL.lock.status)
      end
    end
  end

  desc "acquire", "Acquire the deploy lock"
  option :message, aliases: "-m", type: :string, desc: "A lock message", required: true
  def acquire
    message = options[:message]
    ensure_run_directory

    raise_if_locked do
      on(KAMAL.primary_host) do
        execute *KAMAL.lock.acquire(message, KAMAL.config.version), verbosity: :debug
      end
      say "Acquired the deploy lock"
    end
  end

  desc "release", "Release the deploy lock"
  def release
    handle_missing_lock do
      on(KAMAL.primary_host) do
        execute *KAMAL.lock.release, verbosity: :debug
      end
      say "Released the deploy lock"
    end
  end

  private
    def handle_missing_lock
      yield
    rescue SSHKit::Runner::ExecuteError => e
      if e.message =~ /No such file or directory/
        say "There is no deploy lock"
      else
        raise
      end
    end
end
