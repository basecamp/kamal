class Kamal::Configuration::Validator::Proxy < Kamal::Configuration::Validator
  def validate!
    unless config.nil?
      super

      if config["host"].blank? && config["hosts"].blank? && config["ssl"]
        error "Must set a host to enable automatic SSL"
      end

      if (config.keys & [ "host", "hosts" ]).size > 1
        error "Specify one of 'host' or 'hosts', not both"
      end

      if config["certificate_pem"].present? && config["private_key_pem"].blank?
        error "Missing private_key_pem setting (required when certificate_pem is present)"
      end

      if config["private_key_pem"].present? && config["certificate_pem"].blank?
        error "Missing certificate_pem setting (required when private_key_pem is present)"
      end
    end
  end
end
