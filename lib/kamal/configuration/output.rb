class Kamal::Configuration::Output
  include Kamal::Configuration::Validation

  attr_reader :output_config

  def initialize(config:)
    @output_config = config.raw_config.output || {}
    validate! @output_config unless @output_config.empty?
  end

  def enabled?
    output_config.present?
  end

  def otel
    output_config["otel"]
  end

  def file
    output_config["file"]
  end

  def to_h
    output_config
  end
end
