class Kamal::Cli::Lock < Kamal::Cli::Base
  desc "status", "Report lock status"
  def status
    handle_missing_lock do
      puts capture_lock_status
    end
  end

  desc "acquire", "Acquire the deploy lock"
  option :message, aliases: "-m", type: :string, desc: "A lock message", required: true
  def acquire
    ensure_run_directory

    raise_if_locked do
      execute_lock_acquire(options[:message])
      say "Acquired the deploy lock"
    end
  end

  desc "release", "Release the deploy lock"
  def release
    handle_missing_lock do
      execute_lock_release
      say "Released the deploy lock"
    end
  end

  private
    def handle_missing_lock
      yield
    rescue LockMissingError
      say "There is no deploy lock"
    end
end
