class Kamal::Configuration::Validator::Proxy < Kamal::Configuration::Validator
  HEALTHCHECK_PROTOCOLS = [ "http", "websocket" ].freeze

  def validate!
    unless config.nil?
      super

      if config["host"].blank? && config["hosts"].blank? && config["ssl"]
        error "Must set a host to enable automatic SSL"
      end

      if (config.keys & [ "host", "hosts" ]).size > 1
        error "Specify one of 'host' or 'hosts', not both"
      end

      if config["ssl"].is_a?(Hash)
        if config["ssl"]["certificate_pem"].present? && config["ssl"]["private_key_pem"].blank?
          error "Missing private_key_pem setting (required when certificate_pem is present)"
        end

        if config["ssl"]["private_key_pem"].present? && config["ssl"]["certificate_pem"].blank?
          error "Missing certificate_pem setting (required when private_key_pem is present)"
        end
      end

      if healthcheck = config["healthcheck"]
        protocol = healthcheck["protocol"]

        if protocol.present? && !HEALTHCHECK_PROTOCOLS.include?(protocol)
          error "Invalid healthcheck protocol: #{protocol} (must be one of #{HEALTHCHECK_PROTOCOLS.join(", ")})"
        end

        if healthcheck["websocket_subprotocol"].present? && protocol != "websocket"
          error "Cannot set websocket_subprotocol unless the healthcheck protocol is websocket"
        end
      end

      if run_config = config["run"]
        if run_config["bind_ips"].present?
          ensure_valid_bind_ips(config["bind_ips"])
        end

        if run_config["publish"] == false
          if run_config["bind_ips"].present? || run_config["http_port"].present? || run_config["https_port"].present?
            error "Cannot set http_port, https_port or bind_ips when publish is false"
          end
        end
      end
    end
  end

  private
    def ensure_valid_bind_ips(bind_ips)
      bind_ips.present? && bind_ips.each do |ip|
        next if ip =~ Resolv::IPv4::Regex || ip =~ Resolv::IPv6::Regex
        error "Invalid publish IP address: #{ip}"
      end
    end
end
