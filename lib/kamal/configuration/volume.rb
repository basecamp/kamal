class Kamal::Configuration::Volume
  attr_reader :host_path, :container_path
  delegate :argumentize, to: Kamal::Utils

  def initialize(host_path:, container_path:)
    @host_path = host_path
    @container_path = container_path
  end

  def docker_args
    argumentize "--volume", "#{host_path_for_docker_volume}:#{container_path}"
  end

  private
    def host_path_for_docker_volume
      if Pathname.new(host_path).absolute?
        host_path
      else
        File.join "$(pwd)", host_path
      end
    end
end
