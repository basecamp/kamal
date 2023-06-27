class Mrsk::Configuration::Role
  delegate :argumentize, :argumentize_env_with_secrets, :optionize, to: Mrsk::Utils

  attr_accessor :name

  def initialize(name, config:)
   @name, @config = name.inquiry, config
  end

  def primary_host
    hosts.first
  end

  def hosts
    @hosts ||= extract_hosts_from_config
  end

  def labels
    default_labels.merge(traefik_labels).merge(custom_labels)
  end

  def label_args
    argumentize "--label", labels
  end

  def env
    if config.env && config.env["secret"]
      merged_env_with_secrets
    else
      merged_env
    end
  end

  def env_args
    argumentize_env_with_secrets env
  end

  def health_check_args
    if health_check_cmd.present?
      optionize({ "health-cmd" => health_check_cmd, "health-interval" => health_check_interval })
    else
      []
    end
  end

  def health_check_cmd
    options = specializations["healthcheck"] || {}
    options = config.healthcheck.merge(options) if running_traefik?

    options["cmd"] || http_health_check(port: options["port"], path: options["path"])
  end

  def health_check_interval
    options = specializations["healthcheck"] || {}
    options = config.healthcheck.merge(options) if running_traefik?

    options["interval"] || "1s"
  end

  def cmd
    specializations["cmd"]
  end

  def option_args
    if args = specializations["options"]
      optionize args
    else
      []
    end
  end

  def running_traefik?
    name.web? || specializations["traefik"]
  end

  private
    attr_accessor :config

    def extract_hosts_from_config
      if config.servers.is_a?(Array)
        config.servers
      else
        servers = config.servers[name]
        servers.is_a?(Array) ? servers : Array(servers["hosts"])
      end
    end

    def default_labels
      if config.destination
        { "service" => config.service, "role" => name, "destination" => config.destination }
      else
        { "service" => config.service, "role" => name }
      end
    end

    def traefik_labels
      if running_traefik?
        {
          # Setting a service property ensures that the generated service name will be consistent between versions
          "traefik.http.services.#{traefik_service}.loadbalancer.server.scheme" => "http",

          "traefik.http.routers.#{traefik_service}.rule" => "PathPrefix(`/`)",
          "traefik.http.middlewares.#{traefik_service}-retry.retry.attempts" => "5",
          "traefik.http.middlewares.#{traefik_service}-retry.retry.initialinterval" => "500ms",
          "traefik.http.routers.#{traefik_service}.middlewares" => "#{traefik_service}-retry@docker"
        }
      else
        {}
      end
    end

    def traefik_service
      [ config.service, name, config.destination ].compact.join("-")
    end

    def custom_labels
      Hash.new.tap do |labels|
        labels.merge!(config.labels) if config.labels.present?
        labels.merge!(specializations["labels"]) if specializations["labels"].present?
      end
    end

    def specializations
      if config.servers.is_a?(Array) || config.servers[name].is_a?(Array)
        { }
      else
        config.servers[name].except("hosts")
      end
    end

    def specialized_env
      specializations["env"] || {}
    end

    def merged_env
      config.env&.merge(specialized_env) || {}
    end

    # Secrets are stored in an array, which won't merge by default, so have to do it by hand.
    def merged_env_with_secrets
      merged_env.tap do |new_env|
        # If there's no secret/clear split, everything is clear
        clear_app_env  = config.env["secret"] ? Array(config.env["clear"]) : Array(config.env["clear"] || config.env)
        clear_role_env = specialized_env["secret"] ? Array(specialized_env["clear"]) : Array(specialized_env["clear"] || specialized_env)
        new_env["clear"] = (clear_app_env + clear_role_env).uniq

        secrets_app_env = Array(config.env["secret"])
        secrets_role_env = Array(specialized_env["secret"])
        new_env["secret"] = (secrets_app_env + secrets_role_env).uniq.filter { |secret| filter_secret_env(secret, new_env) }
      end
    end

    def filter_secret_env(secret, new_env)
      # allow clear to override secret
      return false if new_env['clear'].include?(secret)

      # if we find FOO but FOO? exists, we keep the FOO?
      return false if !secret.end_with?('?') && new_env['secret'].include?("#{secret}?")

      true
    end

    def http_health_check(port:, path:)
      "curl -f #{URI.join("http://localhost:#{port}", path)} || exit 1" if path.present? || port.present?
    end
end
