class Kamal::Configuration::Registry
  include Kamal::Configuration::Validation

  def initialize(config:, secrets:, context: "registry")
    @registry_config = config["registry"] || {}
    @secrets = secrets
    validate! registry_config, context: context, with: Kamal::Configuration::Validator::Registry
  end

  def server
    registry_config["server"]
  end

  def username
    lookup("username")
  end

  def password
    lookup("password")
  end

  def local?
    server.to_s.match?("^localhost[:$]")
  end

  def local_port
    local? ? (server.split(":").last.to_i || 80) : nil
  end

  private
    attr_reader :registry_config, :secrets

    def lookup(key)
      if registry_config[key].is_a?(Array)
        secret = secrets[registry_config[key].first]
        # Although the key is present, its value may be empty due to environment
        # variable substitution. I.e. if it refers to an empty or unset env var.
        unless secret.present?
          raise Kamal::ConfigurationError, "The required secret " \
            "'registry.#{key}' does not have a value."
        end

        secret
      else
        registry_config[key]
      end
    end
end
