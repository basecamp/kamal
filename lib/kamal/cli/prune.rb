class Kamal::Cli::Prune < Kamal::Cli::Base
  desc "all", "Prune unused images and stopped containers"
  def all
    modify(lock: true) do
      containers
      images
    end
  end

  desc "images", "Prune unused images"
  def images
    modify(lock: true) do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Pruned images"), verbosity: :debug
        execute *KAMAL.prune.dangling_images
        execute *KAMAL.prune.tagged_images
      end
    end
  end

  desc "containers", "Prune all stopped containers, except the last n (default 5)"
  option :retain, type: :numeric, default: nil, desc: "Number of containers to retain"
  def containers
    retain = options.fetch(:retain, KAMAL.config.retain_containers)
    raise "retain must be at least 1" if retain < 1

    modify(lock: true) do
      on(KAMAL.hosts) do |host|
        protected_ids = []
        if KAMAL.config.any_service_use_proxy_idle?
          # Prune is service-wide even with --roles. Protect sibling roles too.
          roles = KAMAL.config.roles.select { |role| role.running_proxy? && role.hosts.include?(host.to_s) }
          if roles.any?
            begin
              json = capture_with_info(*KAMAL.proxy(host).services)
              containers = KAMAL.prune.registered_containers(json, services: roles.map(&:container_prefix))
              protected_ids = capture_with_info(*KAMAL.prune.inspect_registered_containers(containers)).lines.map(&:strip)
              unless protected_ids.size == containers.size && protected_ids.all? { |id| id.match?(/\A[0-9a-f]{64}\z/) }
                raise ArgumentError, "Invalid container inspection result"
              end
            rescue SSHKit::Command::Failed, JSON::ParserError, KeyError, ArgumentError => e
              warn "Skipping container prune on #{host}: cannot verify proxy targets (#{e.class})"
              next
            end
          end
        end
        execute *KAMAL.auditor.record("Pruned containers"), verbosity: :debug
        execute *KAMAL.prune.app_containers(retain: retain, protected_ids: protected_ids)
      end
    end
  end
end
