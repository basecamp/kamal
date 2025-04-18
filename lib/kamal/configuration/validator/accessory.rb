class Kamal::Configuration::Validator::Accessory < Kamal::Configuration::Validator
  def validate!
    super

    if (config.keys & [ "host", "hosts", "roles" ]).size != 1
      error "specify one of `host`, `hosts` or `roles`"
    end

    validate_docker_options!(config["options"])
  end
end
