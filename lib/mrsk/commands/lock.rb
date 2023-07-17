require "active_support/duration"
require "time"

class Mrsk::Commands::Lock < Mrsk::Commands::Base
  def acquire(message, version)
    combine \
      [:mkdir, lock_dir],
      write_lock_details(message, version)
  end

  def release
    combine \
      [:rm, lock_details_file],
      [:rm, "-r", lock_dir]
  end

  def status
    combine \
      stat_lock_dir,
      read_lock_details
  end

  private
    def write_lock_details(message, version)
      write \
        [:echo, "\"#{Base64.encode64(lock_details(message, version))}\""],
        lock_details_file
    end

    def read_lock_details
      pipe \
        [:cat, lock_details_file],
        [:base64, "-d"]
    end

    def stat_lock_dir
      write \
        [:stat, lock_dir],
        "/dev/null"
    end

    def lock_dir
      "mrsk_lock-#{config.service}"
    end

    def lock_details_file
      [lock_dir, :details].join("/")
    end

    def lock_details(message, version)
      <<~DETAILS.strip
        Locked by: #{locked_by} at #{Time.now.utc.iso8601}
        Version: #{version}
        Message: #{message}
      DETAILS
    end

    def locked_by
      `git config user.name`.strip
    rescue Errno::ENOENT
      "Unknown"
    end
end
