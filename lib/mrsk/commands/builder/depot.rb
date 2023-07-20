class Mrsk::Commands::Builder::Depot < Mrsk::Commands::Builder::Base
  def create
    # No-op on native without cache
  end

  def remove
    # No-op on native without cache
  end

  def push
    depot :build,
      "--push",
      *platforms,
      *build_options,
      build_context
  end

  def info
    # No-op on native
  end

  private
    def depot(*args)
      args.compact.unshift :depot
    end

    def platforms
      if depot_options.is_a?(Hash) && !!depot_options["platforms"]
        ["--platform", depot_options["platforms"].join(",")]
      else
        []
      end
    end

    def depot_options
      config.builder.depot_options
    end
end
