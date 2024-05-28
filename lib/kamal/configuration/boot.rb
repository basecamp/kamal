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
end
