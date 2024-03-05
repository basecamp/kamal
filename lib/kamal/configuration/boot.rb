class Kamal::Configuration::Boot
  def initialize(config:)
    @options = config.raw_config.boot || {}
    @host_count = config.all_hosts.count
  end

  def limit
    limit = @options["limit"]

    if limit.to_s.end_with?("%")
      [ @host_count * limit.to_i / 100, 1 ].max
    else
      limit
    end
  end

  def wait
    @options["wait"]
  end
end
