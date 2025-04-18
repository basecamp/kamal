class Kamal::Configuration::Servers
  include Kamal::Configuration::Validation

  attr_reader :config, :servers_config, :roles

  def initialize(config:)
    @config = config
    @servers_config = config.raw_config.servers
    validate! servers_config, with: Kamal::Configuration::Validator::Servers

    @roles = role_names.map { |role_name| Kamal::Configuration::Role.new role_name, config: config }
  end

  private
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
