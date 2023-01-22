class Mrsk::Configuration::Assessory
  delegate :argumentize, :argumentize_env_with_secrets, to: Mrsk::Utils

  attr_accessor :name, :specifics

  def initialize(name, config:)
    @name, @config, @specifics = name.inquiry, config, config.raw_config["accessories"][name]
  end

  def service_name
    "#{config.service}-#{name}"
  end

  def image
    specifics["image"]
  end

  def host
    specifics["host"] || raise(ArgumentError, "Missing host for accessory")
  end

  def port
    if specifics["port"].to_s.include?(":")
      specifics["port"]
    else
      "#{specifics["port"]}:#{specifics["port"]}"
    end
  end

  def labels
    default_labels.merge(specifics["labels"] || {})
  end

  def label_args
    argumentize "--label", labels
  end

  def env
    specifics["env"] || {}
  end

  def env_args
    argumentize_env_with_secrets env
  end

  def volumes
    specifics["volumes"] || []
  end

  def volume_args
    argumentize "--volume", volumes
  end

  private
    attr_accessor :config

    def default_labels
      { "service" => service_name }
    end
end
