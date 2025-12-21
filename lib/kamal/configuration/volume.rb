class Kamal::Configuration::Volume
  attr_reader :host_path, :container_path, :options
  delegate :argumentize, to: Kamal::Utils

  def initialize(host_path:, container_path:, options: nil)
    @host_path = host_path
    @container_path = container_path
    @options = options
  end

  def docker_args
    argumentize "--volume", docker_args_string
  end

  def docker_args_string
    volume_string = "#{host_path_for_docker_volume}:#{container_path}"
    volume_string += ":#{options}" if options.present?
    volume_string
  end

  private
    def host_path_for_docker_volume
      if Pathname.new(host_path).absolute?
        host_path
      else
        "$PWD/#{host_path}"
      end
    end
end
