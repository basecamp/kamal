class Kamal::Configuration::Healthcheck
  include Kamal::Configuration::Validation

  attr_reader :healthcheck_config

  def initialize(healthcheck_config:, context: "healthcheck")
    @healthcheck_config = healthcheck_config || {}
    validate! @healthcheck_config, context: context
  end

  def merge(other)
    self.class.new healthcheck_config: healthcheck_config.deep_merge(other.healthcheck_config)
  end

  def cmd
    healthcheck_config.fetch("cmd", http_health_check)
  end

  def port
    healthcheck_config.fetch("port", 3000)
  end

  def path
    healthcheck_config.fetch("path", "/up")
  end

  def max_attempts
    healthcheck_config.fetch("max_attempts", 7)
  end

  def interval
    healthcheck_config.fetch("interval", "1s")
  end

  def cord
    healthcheck_config.fetch("cord", "/tmp/kamal-cord")
  end

  def log_lines
    healthcheck_config.fetch("log_lines", 50)
  end

  def set_port_or_path?
    healthcheck_config["port"].present? || healthcheck_config["path"].present?
  end

  def to_h
    {
      "cmd" => cmd,
      "interval" => interval,
      "max_attempts" => max_attempts,
      "port" => port,
      "path" => path,
      "cord" => cord,
      "log_lines" => log_lines
    }
  end

  private
    def http_health_check
      "curl -f #{URI.join("http://localhost:#{port}", path)} || exit 1" if path.present? || port.present?
    end
end
