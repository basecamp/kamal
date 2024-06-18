class Kamal::Configuration::Logging
  delegate :optionize, :argumentize, to: Kamal::Utils

  include Kamal::Configuration::Validation

  attr_reader :logging_config

  def initialize(logging_config:, context: "logging")
    @logging_config = logging_config || {}
    validate! @logging_config, context: context
  end

  def driver
    logging_config["driver"]
  end

  def options
    logging_config.fetch("options", {})
  end

  def merge(other)
    self.class.new logging_config: logging_config.deep_merge(other.logging_config)
  end

  def args
    if driver.present? || options.present?
      optionize({ "log-driver" => driver }.compact) +
        argumentize("--log-opt", options)
    else
      argumentize("--log-opt", { "max-size" => "10m" })
    end
  end
end
