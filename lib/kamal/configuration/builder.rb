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

  def multiarch?
    builder_config["multiarch"] != false
  end

  def local?
    !!builder_config["local"]
  end

  def remote?
    !!builder_config["remote"]
  end

  def cached?
    !!builder_config["cache"]
  end

  def args
    builder_config["args"] || {}
  end

  def secrets
    builder_config["secrets"] || []
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

  def local_arch
    builder_config["local"]["arch"] if local?
  end

  def local_host
    builder_config["local"]["host"] if local?
  end

  def remote_arch
    builder_config["remote"]["arch"] if remote?
  end

  def remote_host
    builder_config["remote"]["host"] if remote?
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

  private
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
      [ "type=registry", builder_config["cache"]&.fetch("options", nil), "ref=#{cache_image_ref}" ].compact.join(",")
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
end
