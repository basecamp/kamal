class Kamal::Configuration::Validator::Role < Kamal::Configuration::Validator
  def validate!
    validate_type! config, Array, Hash

    if config.is_a?(Array)
      validate_servers! "servers", config
    else
      super
    end
  end
end
