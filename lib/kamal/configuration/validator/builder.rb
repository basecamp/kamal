class Kamal::Configuration::Validator::Builder < Kamal::Configuration::Validator
  def validate!
    super

    if config["cache"] && config["cache"]["type"]
      error "Invalid cache type: #{config["cache"]["type"]}" unless [ "gha", "registry" ].include?(config["cache"]["type"])
    end

    error "Builder arch not set" unless config["arch"].present?

    error "buildpacks only support building for one arch" if config["pack"] && config["arch"].is_a?(Array) && config["arch"].size > 1

    error "Cannot disable local builds, no remote is set" if config["local"] == false && config["remote"].blank?

    if config.key?("prune")
      error "prune must be a size, e.g. 5gb" unless Kamal::Utils.docker_size?(config["prune"])
      error "prune is not supported with buildpacks" if config["pack"]
      error "prune is not supported with the docker driver" if config["driver"] == "docker"
      error "prune is not supported with Docker Build Cloud" if config["driver"].to_s.start_with?("cloud")
    end
  end
end
