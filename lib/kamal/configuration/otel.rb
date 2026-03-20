class Kamal::Configuration::Otel
  include Kamal::Configuration::Validation

  attr_reader :otel_config

  def initialize(config:)
    @otel_config = config.raw_config.otel || {}
    validate! otel_config unless otel_config.empty?
  end

  def enabled?
    endpoint.present?
  end

  def endpoint
    otel_config["endpoint"]
  end

  def to_h
    otel_config
  end
end
