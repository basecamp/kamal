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

  def files
    specifics["files"]&.to_h do |local_to_remote_mapping|
      local_file, remote_file = local_to_remote_mapping.split(":")
      [ expand_local_file(local_file), expand_remote_file(remote_file) ]
    end || {}
  end

  def volumes
    (specifics["volumes"] || []) + remote_files_as_volumes
  end

  def volume_args
    argumentize "--volume", volumes
  end

  private
    attr_accessor :config

    def default_labels
      { "service" => service_name }
    end

    def expand_local_file(local_file)
      if local_file.end_with?("erb")
        read_dynamic_file(local_file)
      else
        Pathname.new(File.expand_path(local_file)).to_s
      end
    end

    def expand_remote_file(remote_file)
      service_name + remote_file
    end

    def remote_files_as_volumes
      specifics["files"]&.collect do |local_to_remote_mapping|
        _, remote_file = local_to_remote_mapping.split(":")
        "$PWD/#{expand_remote_file(remote_file)}:#{remote_file}"
      end || []
    end

    def read_dynamic_file(local_file)
      StringIO.new(ERB.new(IO.read(local_file)).result)
    end
end
