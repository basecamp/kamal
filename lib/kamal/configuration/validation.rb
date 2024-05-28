require "yaml"
require "active_support/inflector"

module Kamal::Configuration::Validation
  extend ActiveSupport::Concern

  class_methods do
    def validation_doc
      @validation_doc ||= File.read(File.join(File.dirname(__FILE__), "docs", "#{validation_config_key}.yml"))
    end

    def validation_config_key
      @validation_config_key ||= name.demodulize.underscore
    end
  end

  def validate!(config, example: nil, context: nil, with: Kamal::Configuration::Validator)
    context ||= self.class.validation_config_key
    example ||= validation_yml[self.class.validation_config_key]

    with.new(config, example: example, context: context).validate!
  end

  def validation_yml
    @validation_yml ||= YAML.load(self.class.validation_doc)
  end
end
