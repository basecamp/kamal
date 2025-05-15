class Kamal::Configuration::Validator::Proxy < Kamal::Configuration::Validator
  def validate!
    unless config.nil?
      super

      # Skip SSL host validation when a loadbalancer is present
      # since SSL is disabled when using a loadbalancer
      if config["host"].blank? && config["hosts"].blank? && config["ssl"] && config["loadbalancer"].blank?
        error "Must set a host to enable automatic SSL"
      end

      if (config.keys & [ "host", "hosts" ]).size > 1
        error "Specify one of 'host' or 'hosts', not both"
      end
    end
  end
end
