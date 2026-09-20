class Kamal::Configuration::Logging
  DEFAULT_LOG_MAX_SIZE = "10m"
  DEFAULT_LOG_MAX_SIZE_DRIVERS = %w[ json-file local ].freeze

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

  def args(default_logging_driver: nil)
    if driver.present? || options.present?
      optionize({ "log-driver" => driver }.compact) +
        argumentize("--log-opt", options)
    elsif self.class.default_log_max_size_driver?(default_logging_driver)
      argumentize("--log-opt", { "max-size" => DEFAULT_LOG_MAX_SIZE })
    else
      []
    end
  end

  def self.default_log_max_size_driver?(driver)
    driver.blank? || DEFAULT_LOG_MAX_SIZE_DRIVERS.include?(driver.to_s.strip)
  end
end
