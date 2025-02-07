class Kamal::Commands::Auditor < Kamal::Commands::Base
  attr_reader :details

  def initialize(config, **details)
    super(config)
    @details = details
  end

  # Runs remotely
  def record(line, **details)
    combine \
      [ :mkdir, "-p", config.run_directory ],
      append(
        [ :echo, audit_tags(**details).except(:version, :service_version, :service).to_s.inspect, line.inspect ],
        audit_log_file
      )
  end

  def reveal
    [ :tail, "-n", 50, audit_log_file ]
  end

  private
    def audit_log_file
      file = [ config.service, config.destination, "audit.log" ].compact.join("-")

      File.join(config.run_directory, file)
    end

    def audit_tags(**details)
      tags(**self.details, **details)
    end
end
