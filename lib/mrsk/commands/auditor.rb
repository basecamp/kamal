require "time"

class Mrsk::Commands::Auditor < Mrsk::Commands::Base
  attr_reader :details

  def initialize(config, **details)
    super(config)
    @details = default_details.merge(details)
  end

  # Runs remotely
  def record(line, **details)
    append \
      [ :echo, *audit_tags(**details), line ],
      audit_log_file
  end

  # Runs locally
  def broadcast(line, **details)
    if broadcast_cmd = config.audit_broadcast_cmd
      [ broadcast_cmd, *broadcast_args(line, **details), env: env_for(event: line, **details) ]
    end
  end

  def reveal
    [ :tail, "-n", 50, audit_log_file ]
  end

  private
    def audit_log_file
      [ "mrsk", config.service, config.destination, "audit.log" ].compact.join("-")
    end

    def default_details
      { recorded_at: Time.now.utc.iso8601,
        performer: `whoami`.chomp,
        destination: config.destination }
    end

    def audit_tags(**details)
      tags_for **self.details.merge(details)
    end

    def broadcast_args(line, **details)
      "'#{broadcast_tags(**details).join(" ")} #{line}'"
    end

    def broadcast_tags(**details)
      tags_for **self.details.merge(details).except(:recorded_at)
    end

    def tags_for(**details)
      details.compact.values.map { |value| "[#{value}]" }
    end

    def env_for(**details)
      self.details.merge(details).compact.transform_keys { |detail| "MRSK_#{detail.upcase}" }
    end
end
