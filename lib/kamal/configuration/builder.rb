class Kamal::Configuration::Builder
  include Kamal::Configuration::Validation

  attr_reader :config, :builder_config
  delegate :image, :service, to: :config
  delegate :server, to: :"config.registry"

  def initialize(config:)
    @config = config
    @builder_config = config.raw_config.builder || {}
    @image = config.image
    @server = config.registry.server
    @service = config.service

    validate! builder_config, with: Kamal::Configuration::Validator::Builder
  end

  def to_h
    builder_config
  end

  def remote
    builder_config["remote"]
  end

  def arches
    Array(builder_config.fetch("arch", default_arch))
  end

  def local_arches
    @local_arches ||= if local_disabled?
      []
    elsif remote
      arches & [ Kamal::Utils.docker_arch ]
    else
      arches
    end
  end

  def remote_arches
    @remote_arches ||= if remote
      arches - local_arches
    else
      []
    end
  end

  def remote?
    remote_arches.any?
  end

  def local?
    !local_disabled? && (arches.empty? || local_arches.any?)
  end

  def cloud?
    driver.start_with? "cloud"
  end

  def cached?
    !!builder_config["cache"]
  end

  def pack?
    !!builder_config["pack"]
  end

  def args
    builder_config["args"] || {}
  end

  def secrets
    (builder_config["secrets"] || []).to_h { |key| [ key, config.secrets[key] ] }
  end

  def dockerfile
    builder_config["dockerfile"] || "Dockerfile"
  end

  def target
    builder_config["target"]
  end

  def context
    builder_config["context"] || "."
  end

  def driver
    builder_config.fetch("driver", "docker-container")
  end

  def pack_builder
    builder_config["pack"]["builder"] if pack?
  end

  def pack_buildpacks
    builder_config["pack"]["buildpacks"] if pack?
  end

  def local_disabled?
    builder_config["local"] == false
  end

  def cache_from
    if cached?
      case builder_config["cache"]["type"]
      when "gha"
        cache_from_config_for_gha
      when "registry"
        cache_from_config_for_registry
      end
    end
  end

  def cache_to
    if cached?
      case builder_config["cache"]["type"]
      when "gha"
        cache_to_config_for_gha
      when "registry"
        cache_to_config_for_registry
      end
    end
  end

  def ssh
    builder_config["ssh"]
  end

  def provenance
    builder_config["provenance"]
  end

  def sbom
    builder_config["sbom"]
  end

  def git_clone?
    Kamal::Git.used? && builder_config["context"].nil?
  end

  def clone_directory
    @clone_directory ||= File.join Dir.tmpdir, "kamal-clones", [ service, pwd_sha ].compact.join("-")
  end

  def build_directory
    @build_directory ||=
      if git_clone?
        File.join clone_directory, repo_basename, repo_relative_pwd
      else
        "."
      end
  end

  def docker_driver?
    driver == "docker"
  end

  private
    def valid?
      if docker_driver?
        raise ArgumentError, "Invalid builder configuration: the `docker` driver does not not support remote builders" if remote
        raise ArgumentError, "Invalid builder configuration: the `docker` driver does not not support caching" if cached?
        raise ArgumentError, "Invalid builder configuration: the `docker` driver does not not support multiple arches" if arches.many?
      end

      if @options["cache"] && @options["cache"]["type"]
        raise ArgumentError, "Invalid cache type: #{@options["cache"]["type"]}" unless [ "gha", "registry" ].include?(@options["cache"]["type"])
      end
    end

    def cache_image
      builder_config["cache"]&.fetch("image", nil) || "#{image}-build-cache"
    end

    def cache_image_ref
      [ server, cache_image ].compact.join("/")
    end

    def cache_from_config_for_gha
      "type=gha"
    end

    def cache_from_config_for_registry
      [ "type=registry", "ref=#{cache_image_ref}" ].compact.join(",")
    end

    def cache_to_config_for_gha
      [ "type=gha", builder_config["cache"]&.fetch("options", nil) ].compact.join(",")
    end

    def cache_to_config_for_registry
      [ "type=registry", "ref=#{cache_image_ref}", builder_config["cache"]&.fetch("options", nil) ].compact.join(",")
    end

    def repo_basename
      File.basename(Kamal::Git.root)
    end

    def repo_relative_pwd
      Dir.pwd.delete_prefix(Kamal::Git.root)
    end

    def pwd_sha
      Digest::SHA256.hexdigest(Dir.pwd)[0..12]
    end

    def default_arch
      docker_driver? ? [] : [ "amd64", "arm64" ]
    end
end
