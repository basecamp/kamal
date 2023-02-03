module Mrsk::Commands::Concerns
  module Repository
    def container_id_for(container_name:)
      docker :container, :ls, "-a", "-f", "name=#{container_name}", "-q"
    end

    def current_running_version
      # FIXME: Find more graceful way to extract the version from "app-version" than using sed and tail!
      pipe \
        docker(:ps, "--filter", "label=service=hey", "--format", '"{{.Names}}"'),
        "sed 's/-/\n/g'",
        "tail -n 1"
    end

    def most_recent_version_from_available_images
      pipe \
        docker(:image, :ls, "--format", '"{{.Tag}}"', config.repository),
        "head -n 1"
    end
  end
end
