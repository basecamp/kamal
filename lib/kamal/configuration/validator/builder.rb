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
      error "prune must be a size, e.g. 5gb" if [ true, false ].include?(config["prune"]) || config["prune"].blank?
      error "prune is not supported with buildpacks" if config["pack"]
    end
  end
end
