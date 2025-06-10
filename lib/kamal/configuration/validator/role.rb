class Kamal::Configuration::Validator::Role < Kamal::Configuration::Validator
  def validate!
    validate_type! config, Array, Hash

    validate_labels!(config["labels"]) if config.key?("labels")

    if config.is_a?(Array)
      validate_servers!(config)
    else
      super
      validate_docker_options!(config["options"])
    end
  end
end
