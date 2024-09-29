class Kamal::Configuration::Validator::Proxy < Kamal::Configuration::Validator
  def validate!
    unless config.nil?
      super

      if config["host"].blank? && config["hosts"].blank? && config["ssl"]
        error "Must set a host to enable automatic SSL"
      end

      if config["host"].present? && config["hosts"].present?
        error "Must use either 'host' or 'hosts', not both"
      end
    end
  end
end
