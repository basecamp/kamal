class Kamal::Configuration::Validator::Builder < Kamal::Configuration::Validator
  def validate!
    super

    if config["cache"] && config["cache"]["type"]
      error "Invalid cache type: #{config["cache"]["type"]}" unless [ "gha", "registry" ].include?(config["cache"]["type"])
    end

    error "Builder arch not set" unless config["arch"].present?

    error "Invalid builder engine: #{config["engine"]}" if config["engine"] && !%w[ docker apple-container ].include?(config["engine"])

    if config["engine"] == "apple-container"
      error "The apple-container engine does not support remote builders" if config["remote"]
      error "The apple-container engine does not support disabling local builds" if config["local"] == false
      error "The apple-container engine does not support buildpacks" if config["pack"]
      error "The apple-container engine does not support cache exports" if config["cache"]
      error "The apple-container engine does not support provenance attestations" if config.key?("provenance")
      error "The apple-container engine does not support SBOM attestations" if config.key?("sbom")
      error "The apple-container engine does not support custom builder drivers" if config["driver"]
      error "The apple-container engine only supports the default SSH agent" if config["ssh"] && !config["ssh"].match?(/\Adefault(?:=.+)?\z/)
    end

    error "buildpacks only support building for one arch" if config["pack"] && config["arch"].is_a?(Array) && config["arch"].size > 1

    error "Cannot disable local builds, no remote is set" if config["local"] == false && config["remote"].blank?
  end
end
