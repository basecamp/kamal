class Kamal::Commands::Auditor < Kamal::Commands::Base
  attr_reader :details
  delegate :escape_shell_value, to: Kamal::Utils

  def initialize(config, **details)
    super(config)
    @details = details
  end

  # Runs remotely
  def record(line, **details)
    combine \
      make_run_directory,
      append([ :echo, escape_shell_value(audit_line(line, **details)) ], audit_log_file)
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

    def make_run_directory
      [ :mkdir, "-p", config.run_directory ]
    end

    def audit_line(line, **details)
      "#{audit_tags(**details).except(:version, :service_version, :service)} #{line}"
    end
end
