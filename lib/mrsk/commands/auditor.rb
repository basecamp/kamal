require "active_support/core_ext/time/conversions"

class Mrsk::Commands::Auditor < Mrsk::Commands::Base
  attr_reader :role

  def initialize(config, role: nil)
    super(config)
    @role = role
  end

  # Runs remotely
  def record(line)
    append \
      [ :echo, tagged_record_line(line) ],
      audit_log_file
  end

  # Runs locally
  def broadcast(line)
    if broadcast_cmd = config.audit_broadcast_cmd
      [ broadcast_cmd, tagged_broadcast_line(line) ]
    end
  end

  def reveal
    [ :tail, "-n", 50, audit_log_file ]
  end

  private
    def audit_log_file
      [ "mrsk", config.service, config.destination, "audit.log" ].compact.join("-")
    end

    def tagged_record_line(line)
      quote [recorded_at_tag, performer_tag, role_tag, line].compact.join(" ")
    end

    def tagged_broadcast_line(line)
      quote [performer_tag, role_tag, line].compact.join(" ")
    end

    def role_tag
      "[#{role}]" if role
    end

    def performer_tag
      "[#{`whoami`.strip}]"
    end

    def recorded_at_tag
      "[#{Time.now.to_fs(:db)}]"
    end

    def quote(tagged_line)
      "'#{tagged_line}'"
    end
end
