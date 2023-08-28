class Kamal::Commands::Traefik::Dynamic < Kamal::Commands::Base
  attr_reader :static_config, :dynamic_config

  def initialize(config, role: nil)
    super(config)
    @static_config = Kamal::Configuration::Traefik::Static.new(config: config)
    @dynamic_config = Kamal::Configuration::Traefik::Dynamic.new(config: config, role: role)
  end

  def run_id
    pipe \
      [:docker, :exec, :traefik, :wget, "-qSO", "/dev/null", "http://localhost:#{Kamal::Configuration::Traefik::Static::CONTAINER_PORT}#{config.healthcheck["path"]}", "2>&1"],
      [:grep, "-i", Kamal::Configuration::Traefik::Dynamic::RUN_ID_HEADER],
      [:cut, "-d ' ' -f 4"]
  end

  def write_config(ip_address:)
    # Write to tmp then mv for an atomic copy. If you write directly traefik sees an empty file
    # and removes the service before picking up the new config.
    temp_config_file = "/tmp/kamal-traefik-config-#{rand(10000000)}"
    chain \
      write([:echo, dynamic_config.config(ip_address: ip_address).to_yaml.shellescape], temp_config_file),
      [:mv, temp_config_file, host_file]
  end

  def remove_config
    [:rm, host_file]
  end

  def boot_check?
    dynamic_config.boot_check?
  end

  def config_run_id
    dynamic_config.run_id
  end

  private
    def host_file
      "#{static_config.host_directory}/#{dynamic_config.host_file}"
    end
end

