class Kamal::Configuration::Output
  include Kamal::Configuration::Validation

  attr_reader :output_config

  def initialize(config:)
    @output_config = config.raw_config.output || {}

    # Backwards compat: top-level otel: treated as output: { otel: { ... } }
    if @output_config.empty? && config.raw_config.otel.present?
      @output_config = { "otel" => config.raw_config.otel }
    end

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
