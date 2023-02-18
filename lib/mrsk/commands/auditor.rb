require "active_support/core_ext/time/conversions"

class Mrsk::Commands::Auditor < Mrsk::Commands::Base
  # Runs remotely
  def record(line)
    append \
      [ :echo, tagged_line(line) ],
      audit_log_file
  end

  # Runs locally
  def broadcast(line)
    if broadcast_cmd = config.audit_broadcast_cmd
      pipe \
        [ :echo, tagged_line(line) ],
        broadcast_cmd
    end
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
      "[#{recorded_at}] [#{performer}]"
    end

    def performer
      @performer ||= `whoami`.strip
    end

    def recorded_at
      Time.now.to_fs(:db)
    end
end
