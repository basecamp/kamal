class Kamal::Configuration::Validator::Accessory < Kamal::Configuration::Validator
  def validate!
    super

    if (config.keys & [ "host", "hosts", "roles", "tags" ]).size != 1
      error "specify one of `host`, `hosts`, `roles` or `tags`"
    end

    validate_docker_options!(config["options"])
  end
end
