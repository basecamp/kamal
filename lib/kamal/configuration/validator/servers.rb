class Kamal::Configuration::Validator::Servers < Kamal::Configuration::Validator
  def validate!
    validate_type! config, Array, Hash

    validate_servers! config if config.is_a?(Array)
  end
end
