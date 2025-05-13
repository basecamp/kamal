class Kamal::Configuration::Validator::Sshkit < Kamal::Configuration::Validator
  def validate!
    validate_against_example! \
      config.except("default_env"),
      example.except("default_env")

    if config["default_env"]
      validate_hash_of!(config["default_env"], String)
    end
  end
end
