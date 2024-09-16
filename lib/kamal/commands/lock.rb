require "active_support/duration"
require "time"
require "base64"

class Kamal::Commands::Lock < Kamal::Commands::Base
  def acquire(message, version)
    combine \
      [ :mkdir, lock_dir ],
      write_lock_details(message, version)
  end

  def release
    combine \
      [ :rm, lock_details_file ],
      [ :rm, "-r", lock_dir ]
  end

  def status
    combine \
      stat_lock_dir,
      read_lock_details
  end

  def ensure_locks_directory
    [ :mkdir, "-p", locks_dir ]
  end

  private
    def write_lock_details(message, version)
      write \
        [ :echo, "\"#{Base64.encode64(lock_details(message, version))}\"" ],
        lock_details_file
    end

    def read_lock_details
      pipe \
        [ :cat, lock_details_file ],
        [ :base64, "-d" ]
    end

    def stat_lock_dir
      write \
        [ :stat, lock_dir ],
        "/dev/null"
    end

    def lock_dir
      dir_name = [ "lock", config.service, config.destination ].compact.join("-")

      File.join(config.run_directory, dir_name)
    end

    def lock_details_file
      File.join(lock_dir, "details")
    end

    def lock_details(message, version)
      <<~DETAILS.strip
        Locked by: #{locked_by} at #{Time.now.utc.iso8601}
        Version: #{version}
        Message: #{message}
      DETAILS
    end

    def locked_by
      Kamal::Git.user_name
    rescue Errno::ENOENT
      "Unknown"
    end
end
