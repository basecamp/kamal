class Kamal::Configuration::Validator::Ssh < Kamal::Configuration::Validator
  SPECIAL_KEYS = [ "config" ]

  def validate!
    validate_against_example! \
      config.except(*SPECIAL_KEYS),
      example.except(*SPECIAL_KEYS)

    validate_config_key! if config.key?("config")
  end

  private

  def validate_config_key!
    with_context(config["config"]) do
      validate_type! config["config"], TrueClass, String
    end
  end
end
