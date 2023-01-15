class Mrsk::Configuration::Validator
  delegate :argumentize, to: Mrsk::Configuration

  def initialize config
    @config = config
    @errors = []
  end

  def validate
    required_configuration
    servers
    service
    image
    registry
    @errors
  end

  private
    attr_accessor :config, :errors

    def required_configuration
      %i[ service image registry ].each do |key|
        errors << "Missing required configuration for #{key}" unless config[key].present?
      end

      %w[ username password ].each do |key|
        errors << "Missing required configuration for registry/#{key}" unless config.registry[key].present?
      end
    end

    def servers
      validate_servers config.servers

      if config.servers.is_a?(Hash)
        validate_servers(config.servers['web'], type: :web)
        validate_job_servers config.servers['job'] if config.servers['job'].present?
      end
    end

    def service
      errors << 'Service name must be present' if config.service.nil?
      errors << 'Service must include lowercase letters, digits or dashes' if config.service !~ /\A[a-z0-9\-]+\z/
    end

    def image
      errors << 'The container image must be present' if config.image.nil?
      errors << 'The container image must be created from the username/image' unless Regexp.new('[A-Za-z0-9]+/[A-Za-z0-9]+', Regexp::IGNORECASE).match(config.image)
    end

    def registry
      errors << "If you are not using Docker Hub, specify a registry server: registry.digitalocean.com / ghcr.io / registry.gitlab.com ..." \
        if config.registry.keys.include?('server') && config.registry['server'].nil?
    end

    def validate_job_servers job
      errors << "Your job servers configuration must be a Hash and contain the `hosts`` key and a custom entrypoint command `cmd` key" unless job.is_a?(Hash)
      errors << "Your `servers.job.hosts` key must be an Array of servers ips" unless job["hosts"].is_a?(Array)
      errors << "Your `servers.job.cmd` key must be an String with the entrypoint command to start your service" unless job["cmd"].is_a?(String)
    end

    def validate_servers(servers, type: nil)
      validate_required_ips(servers, type: type)
      validate_if_servers_are_array_or_hash(servers, type: type)
      servers.each { |server| validate_server_ip server } if servers.is_a?(Array)
    end

    def validate_if_servers_are_array_or_hash(servers, type: nil)
      errors << "Your #{type} servers configuration must be an Array or Hash" unless servers.is_a?(Array) || servers.is_a?(Hash)
    end

    def validate_required_ips(servers, type: nil)
      errors << "Missing required IPs on your #{type} servers configuration" unless servers.present?
    end

    def validate_server_ip server
      errors << "The IP address #{server} must be a valid IPv4 public IP address from your provider" unless \
      Regexp.new('^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$', Regexp::IGNORECASE).match(server)
    end
end