class Mrsk::Configuration::Builder
  def initialize(config:)
    @options = config.raw_config.builder || {}
    @image = config.image
    @server = config.registry["server"]

    valid?
  end

  def to_h
    @options
  end

  def multiarch?
    @options["multiarch"] != false
  end

  def local?
    !!@options["local"]
  end

  def remote?
    !!@options["remote"]
  end

  def cached?
    !!@options["cache"]
  end

  def args
    @options["args"] || {}
  end

  def secrets
    @options["secrets"] || []
  end

  def dockerfile
    @options["dockerfile"] || "Dockerfile"
  end

  def context
    @options["context"] || "."
  end

  def local_arch
    @options["local"]["arch"] if local?
  end

  def local_host
    @options["local"]["host"] if local?
  end

  def remote_arch
    @options["remote"]["arch"] if remote?
  end

  def remote_host
    @options["remote"]["host"] if remote?
  end

  def cache_from
    if cached?
      case @options["cache"]["type"]
      when "gha"
        cache_from_config_for_gha
      when "registry"
        cache_from_config_for_registry
      end
    end
  end

  def cache_to
    if cached?
      case @options["cache"]["type"]
      when "gha"
        cache_to_config_for_gha
      when "registry"
        cache_to_config_for_registry
      end
    end
  end

  private
    def valid?
      if @options["local"] && !@options["remote"]
        raise ArgumentError, "You must specify both local and remote builder config for remote multiarch builds"
      end

      if @options["cache"] && @options["cache"]["type"]
        raise ArgumentError, "Invalid cache type: #{@options["cache"]["type"]}" unless ["gha", "registry"].include?(@options["cache"]["type"])
      end
    end

    def cache_image
      @options["cache"]&.fetch("image", nil) || "#{@image}-build-cache"
    end

    def cache_from_config_for_gha
      "type=gha"
    end

    def cache_from_config_for_registry
      [ "type=registry", "ref=#{@server}/#{cache_image}" ].compact.join(",")
    end

    def cache_to_config_for_gha
      [ "type=gha", @options["cache"]&.fetch("options", nil)].compact.join(",")
    end

    def cache_to_config_for_registry
      [ "type=registry", @options["cache"]&.fetch("options", nil), "ref=#{@server}/#{cache_image}" ].compact.join(",")
    end
end
