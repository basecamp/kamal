class Kamal::Commander::Specifics
  attr_reader :primary_host, :primary_role, :hosts, :roles
  delegate :stable_sort!, to: Kamal::Utils

  def initialize(config, specific_hosts, specific_roles)
    @config, @specific_hosts, @specific_roles = config, specific_hosts, specific_roles

    @roles, @hosts = specified_roles, specified_hosts

    @primary_host = specific_hosts&.first || primary_specific_role&.primary_host || config.primary_host
    @primary_role = primary_or_first_role(roles_on(primary_host))

    stable_sort!(roles) { |role| role == primary_role ? 0 : 1 }
    stable_sort!(hosts) { |host| roles_on(host).any? { |role| role == primary_role } ? 0 : 1 }
  end

  def roles_on(host)
    roles.select { |role| role.hosts.include?(host.to_s) }
  end

  def proxy_hosts
    config.proxy_hosts & specified_hosts
  end

  def accessory_hosts
    config.accessories.flat_map(&:hosts) & specified_hosts
  end

  private
    attr_reader :config, :specific_hosts, :specific_roles

    def primary_specific_role
      primary_or_first_role(specific_roles) if specific_roles.present?
    end

    def primary_or_first_role(roles)
      roles.detect { |role| role == config.primary_role } || roles.first
    end

    def specified_roles
      (specific_roles || config.roles) \
        .select { |role| ((specific_hosts || config.all_hosts) & role.hosts).any? }
    end

    def specified_hosts
      specified_hosts = specific_hosts || config.all_hosts

      if (specific_role_hosts = specific_roles&.flat_map(&:hosts)).present?
        specified_hosts.select { |host| specific_role_hosts.include?(host) }
      else
        specified_hosts
      end
    end
end
