class Mrsk::Cli::Lock < Mrsk::Cli::Base
  desc "status", "Report lock status"
  def status
    handle_missing_lock do
      on(MRSK.primary_host) { puts capture_with_info(*MRSK.lock.status) }
    end
  end

  desc "acquire", "Acquire the deploy lock"
  option :message, aliases: "-m", type: :string, desc: "A lock mesasge", required: true
  def acquire
    message = options[:message]
    handle_missing_lock do
      on(MRSK.primary_host) { execute *MRSK.lock.acquire(message, MRSK.config.version) }
      say "Set the deploy lock"
    end
  end

  desc "release", "Release the deploy lock"
  def release
    handle_missing_lock do
      on(MRSK.primary_host) { execute *MRSK.lock.release }
      say "Removed the deploy lock"
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
