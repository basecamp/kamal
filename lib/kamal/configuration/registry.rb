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

  # `auto` is the container CLI's own default, and it cannot reach a plain-HTTP
  # registry: 1.2.2 attempts TLS for localhost and 127.0.0.1 alike and fails with
  # "bad protocol version". Treat it as "let Kamal decide".
  def scheme
    configured = registry_config["scheme"]
    configured = nil if configured == "auto"

    configured || ("http" if local?)
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
        secrets[registry_config[key].first]
      else
        registry_config[key]
      end
    end
end
