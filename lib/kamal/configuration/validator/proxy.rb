class Kamal::Configuration::Validator::Proxy < Kamal::Configuration::Validator
  def validate!
    super

    if config["host"].blank? && config["ssl"]
      error "Must set a host to enable automatic SSL"
    end
  end
end
