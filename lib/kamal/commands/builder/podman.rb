class Kamal::Commands::Builder::Podman < Kamal::Commands::Builder::Base
  # Podman has no buildx/buildkit, so there's no persistent builder instance to
  # create, remove, or inspect. These no-op exactly like the docker-driver path.
  def create
  end

  def remove
  end

  def inspect_builder
  end

  def info
    docker :version
  end

  # `podman build` (no buildx) then push each tag, since Podman can't stream the
  # build straight to a registry the way `buildx --output=type=registry` does.
  def push(export_action = "registry", tag_as_dirty: false, no_cache: false)
    combine \
      build(tag_as_dirty: tag_as_dirty, no_cache: no_cache),
      *(build_tag_names(tag_as_dirty: tag_as_dirty).map { |tag| docker(:push, tag) } if export_action == "registry")
  end

  private
    def build(tag_as_dirty:, no_cache:)
      docker :build,
        *platform_options(arches),
        *build_tag_options(tag_as_dirty: tag_as_dirty),
        *build_options,
        *([ "--no-cache" ] if no_cache),
        build_context,
        "2>&1"
    end

    def builder_name
      "kamal-podman"
    end
end
