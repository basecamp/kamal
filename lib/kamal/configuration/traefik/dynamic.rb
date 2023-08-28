class Kamal::Configuration::Traefik::Dynamic
  RUN_ID_HEADER = "X-Kamal-Run-ID"

  delegate :argumentize, :argumentize_env_with_secrets, :optionize, to: Kamal::Utils

  attr_reader :traefik_config, :role_config, :role_traefik_config

  def initialize(config:, role:)
    @traefik_config = config.traefik || {}
    @role_config = config.role(role)
    @role_traefik_config = role_config&.traefik || {}
  end

  def host_file
    "#{role_config.full_name}.yml"
  end

  def config(ip_address:)
    default_config(ip_address:).deep_merge!(custom_config)
  end

  def boot_check?
    role_traefik_config.fetch("boot_check") { traefik_config.fetch("boot_check", true) }
  end

  def run_id
    @run_id ||= SecureRandom.hex(16)
  end

  private
    def default_config(ip_address:)
      run_id_header_middleware = "#{role_config.full_name}-id-header"

      {
        "http" => {
          "routers" => {
            role_config.full_name => {
              "rule" => "PathPrefix(`/`)",
              "middlewares" => [ run_id_header_middleware ],
              "service" => role_config.full_name
            }
          },
          "services" => {
            role_config.full_name => {
              "loadbalancer" => {
                "servers" => [ { "url" => "http://#{ip_address}:80" } ]
              }
            }
          },
          "middlewares" => {
            run_id_header_middleware => {
              "headers" => {
                "customresponseheaders" => {
                  RUN_ID_HEADER => run_id
                }
              }
            }
          }
        }
      }
    end

    def custom_config
      traefik_config.fetch("dynamic", {}).deep_merge(role_traefik_config.fetch("dynamic", {}))
    end
end
