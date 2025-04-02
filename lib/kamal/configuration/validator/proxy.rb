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

      if config["ssl_certificate_path"].present? && config["ssl_private_key_path"].blank?
        error "Must set a private key path to use a custom SSL certificate"
      end

      if config["ssl_private_key_path"].present? && config["ssl_certificate_path"].blank?
        error "Must set a certificate path to use a custom SSL private key"
      end
    end
  end
end
