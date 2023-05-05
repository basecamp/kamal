class Mrsk::Commands::Auditor < Mrsk::Commands::Base
  attr_reader :details

  def initialize(config, **details)
    super(config)
    @details = details
  end

  # Runs remotely
  def record(line, **details)
    append \
      [ :echo, audit_tags(**details).except(:version).to_s, line ],
      audit_log_file
  end

  # Runs locally
  def broadcast(line, **details)
    if broadcast_cmd = config.audit_broadcast_cmd
      tags = audit_tags(**details, event: line)
      [ broadcast_cmd,  "'#{tags.except(:recorded_at, :event, :version)} #{line}'", env: tags.env ]
    end
  end

  def reveal
    [ :tail, "-n", 50, audit_log_file ]
  end

  private
    def audit_log_file
      [ "mrsk", config.service, config.destination, "audit.log" ].compact.join("-")
    end

    def audit_tags(**details)
      tags(**self.details, **details)
    end
end
