require "active_support/core_ext/time/conversions"

class Mrsk::Commands::Auditor < Mrsk::Commands::Base
  def record(line)
    append \
      [ :echo, tagged_line(line) ],
      audit_log_file
  end

  def reveal
    [ :tail, "-n", 50, audit_log_file ]
  end

  private
    def audit_log_file
      "mrsk-#{config.service}-audit.log"
    end

    def tagged_line(line)
      "'#{tags} #{line}'"
    end

    def tags
      "[#{timestamp}] [#{performer}]"
    end

    def performer
      `whoami`.strip
    end

    def timestamp
      Time.now.to_fs(:db)
    end
end
