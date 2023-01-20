class Mrsk::Configuration::Role
  delegate :argumentize, to: Mrsk::Utils

  attr_accessor :name

  def initialize(name, config:)
   @name, @config = name.inquiry, config
  end

  def hosts
    @hosts ||= extract_hosts_from_config
  end

  def labels
    if name.web?
      default_labels.merge(traefik_labels).merge(custom_labels)
    else
      default_labels.merge(custom_labels)
    end
  end

  def label_args
    argumentize "--label", labels
  end

  def cmd
    specializations["cmd"]
  end

  private
    attr_accessor :config

    def extract_hosts_from_config
      if config.servers.is_a?(Array)
        config.servers
      else
        servers = config.servers[name]
        servers.is_a?(Array) ? servers : servers["hosts"]
      end
    end

    def default_labels
      { "service" => config.service, "role" => name }
    end

    def traefik_labels
      {
        "traefik.http.routers.#{config.service}.rule" => "'PathPrefix(`/`)'",
        "traefik.http.services.#{config.service}.loadbalancer.healthcheck.path" => "/up",
        "traefik.http.services.#{config.service}.loadbalancer.healthcheck.interval" => "1s",
        "traefik.http.middlewares.#{config.service}.retry.attempts" => "3",
        "traefik.http.middlewares.#{config.service}.retry.initialinterval" => "500ms"
      }
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
        config.servers[name].without("hosts")
      end
    end
end
