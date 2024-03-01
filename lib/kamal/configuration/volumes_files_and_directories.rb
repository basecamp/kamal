class Kamal::Configuration::VolumesFilesAndDirectories
  delegate :argumentize, :optionize, to: Kamal::Utils
  delegate :argumentize, to: Kamal::Utils

  def initialize(service_name, config)
    @config = config
    @service_name = service_name
  end

  def volume_args
    argumentize "--volume", volumes
  end

  def directories
    config["directories"]&.to_h do |host_to_container_mapping|
      host_path, container_path = host_to_container_mapping.split(":")
      [ expand_host_path(host_path), container_path ]
    end || {}
  end

  def directories_to_upload
    local_to_remote_mapping(config["directories"])
  end

  def files
    local_to_remote_mapping(config["files"])
  end

  private
    attr_reader :config, :service_name

    def local_to_remote_mapping(to_map)
      to_map&.to_h do |local_to_remote_mapping|
        local_file, remote_file = local_to_remote_mapping.split(":")
        [ expand_local_file(local_file), expand_remote_file(remote_file) ]
      end || {}
    end

    def env
      config["env"] || {}
    end

    def volumes
      config_volumes + remote_files_as_volumes + remote_directories_as_volumes
    end

    def with_clear_env_loaded
      (env["clear"] || env).each { |k, v| ENV[k] = v }
      yield
    ensure
      (env["clear"] || env).each { |k, v| ENV.delete(k) }
    end

    def read_dynamic_file(local_file)
      StringIO.new(ERB.new(IO.read(local_file)).result)
    end

    def expand_local_file(local_file)
      if local_file.end_with?("erb")
        with_clear_env_loaded { read_dynamic_file(local_file) }
      else
        Pathname.new(File.expand_path(local_file)).to_s
      end
    end

    def expand_remote_file(remote_file)
      service_name + remote_file
    end

    def config_volumes
      config["volumes"] || []
    end

    def remote_files_as_volumes
      config["files"]&.collect do |local_to_remote_mapping|
        _, remote_file = local_to_remote_mapping.split(":")
        "#{service_data_directory + remote_file}:#{remote_file}"
      end || []
    end

    def remote_directories_as_volumes
      config["directories"]&.collect do |host_to_container_mapping|
        host_path, container_path = host_to_container_mapping.split(":")
        [ expand_host_path(host_path), container_path ].join(":")
      end || []
    end

    def absolute_path?(path)
      Pathname.new(path).absolute?
    end

    def expand_host_path(host_path)
      absolute_path?(host_path) ? host_path : "#{service_data_directory}/#{host_path}"
    end

    def service_data_directory
      "$PWD/#{service_name}"
    end
end
