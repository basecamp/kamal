require "active_support/ordered_options"
require "erb"

class Mrsk::Configuration
  delegate :service, :image, :env, :registry, :ssh_user, to: :config, allow_nil: true

  def self.load_file(file)
    if file.exist?
      new YAML.load(ERB.new(IO.read(file)).result).symbolize_keys
    else
      raise "Configuration file not found in #{file}"
    end
  end

  def initialize(config)
    @config = ActiveSupport::InheritableOptions.new(config)
    ensure_required_keys_present
  end

  def hosts
    ENV["HOSTS"] || config.servers
  end
  end

  def version
    @version ||= ENV["VERSION"] || `git rev-parse HEAD`.strip
  end

  def repository
    [ config.registry["server"], image ].compact.join("/")
  end

  def absolute_image
    "#{repository}:#{version}"
  end

  def service_with_version
    "#{service}-#{version}"
  end

  def envs
    parameterize "-e", env if env.present?
  end

  def labels
    parameterize "--label", \
      "service" => service,
      "traefik.http.routers.#{service}.rule" => "'PathPrefix(`/`)'",
      "traefik.http.services.#{service}.loadbalancer.healthcheck.path" => "/up",
      "traefik.http.services.#{service}.loadbalancer.healthcheck.interval" => "1s",
      "traefik.http.middlewares.#{service}.retry.attempts" => "3",
      "traefik.http.middlewares.#{service}.retry.initialinterval" => "500ms"
  end

  def ssh_options
    { user: config.ssh_user || "root", auth_methods: [ "publickey" ] }
  end

  def master_key
    ENV["RAILS_MASTER_KEY"] || File.read(Rails.root.join("config/master.key"))
  end

  private
    attr_accessor :config

    def ensure_required_keys_present
      %i[ service image registry ].each do |key|
        raise ArgumentError, "Missing required configuration for #{key}" unless config[key].present?
      end

      %w[ username password ].each do |key|
        raise ArgumentError, "Missing required configuration for registry/#{key}" unless config.registry[key].present?
      end      
    end

    def parameterize(param, hash)
      hash.flat_map { |k, v| [ param, "#{k}=#{v}" ] }
    end
end
