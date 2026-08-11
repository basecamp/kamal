class Kamal::Configuration::Servers
  include Kamal::Configuration::Validation

  attr_reader :config, :servers_config, :roles, :rollout_roles

  def initialize(config:)
    @config = config
    @servers_config = config.raw_config.servers
    validate! servers_config, with: Kamal::Configuration::Validator::Servers

    @roles = role_names.map { |role_name| Kamal::Configuration::Role.new role_name, config: config }
    @rollout_roles = if rollout_configured?
      @roles.select(&:rollout_available?).map do |role|
        Kamal::Configuration::Role.new role.name, config: config, rollout: true
      end
    else
      []
    end
  end

  private
    # Rollouts stay entirely off, and cost nothing, until the config asks for them
    def rollout_configured?
      !config.raw_config.rollout.nil? || servers_config.is_a?(Hash) &&
        servers_config.any? { |_, role_config| role_config.is_a?(Hash) && role_config.key?("rollout") }
    end

    def role_names
      case servers_config
      when Array
        [ "web" ]
      when NilClass
        []
      else
        servers_config.keys.sort
      end
    end
end
