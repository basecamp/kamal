class Kamal::Configuration::Otel
  include Kamal::Configuration::Validation

  attr_reader :otel_config

  def initialize(config:)
    @otel_config = config.raw_config.otel || {}
    @service = config.service
    @destination = config.destination
    validate! otel_config unless otel_config.empty?
  end

  def enabled?
    endpoint.present?
  end

  def endpoint
    otel_config["endpoint"]
  end

  def service_namespace
    @service
  end

  def environment
    @destination
  end

  def to_h
    otel_config
  end
end
