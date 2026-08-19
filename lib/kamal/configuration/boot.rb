class Kamal::Configuration::Boot
  include Kamal::Configuration::Validation

  attr_reader :boot_config, :host_count

  def initialize(config:)
    @boot_config = config.raw_config.boot || {}
    @host_count = config.all_hosts.count
    validate! boot_config
  end

  def limit
    limit = boot_config["limit"]

    if limit.to_s.end_with?("%")
      [ host_count * limit.to_i / 100, 1 ].max
    else
      limit
    end
  end

  def wait
    boot_config["wait"]
  end

  def parallel_roles
    boot_config["parallel_roles"]
  end

  def role_order
    boot_config["role_order"] || []
  end

  def ordered_roles(roles, primary_role:)
    return roles if role_order.empty?

    priorities = role_order.each_with_index.to_h

    roles.each_with_index.sort_by do |role, index|
      [ role == primary_role ? 0 : 1, priorities.fetch(role.name, priorities.length), index ]
    end.map(&:first)
  end
end
