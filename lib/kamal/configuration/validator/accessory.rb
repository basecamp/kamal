class Kamal::Configuration::Validator::Accessory < Kamal::Configuration::Validator
  def validate!
    super

    if (config.keys & [ "host", "hosts", "role", "roles", "tag", "tags" ]).size != 1
      error "specify one of `host`, `hosts`, `role`, `roles`, `tag` or `tags`"
    end

    validate_docker_options!(config["options"])
  end
end
