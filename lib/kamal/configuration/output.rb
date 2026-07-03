class Kamal::Configuration::Output
  include Kamal::Configuration::Validation

  LOGGER_TYPES = {
    "otel" => "Kamal::Output::OtelLogger",
    "file" => "Kamal::Output::FileLogger"
  }

  attr_reader :output_config, :loggers

  def initialize(config:)
    @config = config
    @output_config = config.raw_config.output || {}
    validate! @output_config unless @output_config.empty?
    @loggers = build_loggers
  end

  def enabled?
    output_config.present?
  end

  def to_h
    output_config
  end

  private
    def build_loggers
      output_config.filter_map do |key, settings|
        if (klass_name = LOGGER_TYPES[key])
          klass_name.constantize.build(settings: settings || {}, config: @config)
        end
      end
    end
end
