module Kamal::Rollout
  private
    def rollout_proxy_hosts
      KAMAL.rollout_roles.select(&:running_proxy?).flat_map(&:hosts).uniq & KAMAL.rollout_hosts
    end

    # Turns the split off while remembering it, so enabling needs no arguments
    def set_rollout_enabled(enabled)
      on(rollout_proxy_hosts) do |host|
        role = KAMAL.rollout_roles_on(host).find(&:running_proxy?)
        execute *KAMAL.app(role: role, host: host).rollout_enable(enabled), raise_on_non_zero_exit: false
      end
    end

    # Unregisters the targets, for when the containers are going away
    def unregister_rollout
      on(rollout_proxy_hosts) do |host|
        role = KAMAL.rollout_roles_on(host).find(&:running_proxy?)
        execute *KAMAL.app(role: role, host: host).rollout_stop, raise_on_non_zero_exit: false
      end
    end

    def live_rollouts
      return [] if KAMAL.rollout_roles.empty?

      found = []
      mutex = Mutex.new

      on(KAMAL.rollout_hosts) do |host|
        KAMAL.rollout_roles_on(host).each do |role|
          version = capture_with_info(
            *KAMAL.app(role: role, host: host).current_running_version,
            raise_on_non_zero_exit: false
          ).strip.presence

          mutex.synchronize { found << [ role.name, version ] } if version
        end
      end

      found.uniq
    end

    def handle_live_rollout
      return if (rollouts = live_rollouts).empty?

      summary = rollouts.map { |role, version| "#{role} at #{version}" }.join(", ")

      case KAMAL.config.rollout.on_deploy
      when "keep"
        say "Rollout still live (#{summary}). This deploy leaves it alone, so that cohort stays on the rollout version — run `kamal rollout disable` when you are done with it.", :yellow
      when "disable"
        say "Rollout still live (#{summary}). Disabling it.", :yellow
        set_rollout_enabled false
      when "ask"
        if ask("Rollout still live (#{summary}). Disable it and continue?", limited_to: %w[ y N ], default: "N") == "y"
          set_rollout_enabled false
        else
          raise Kamal::Cli::RolloutError, "Aborted — run `kamal rollout disable` first, or set rollout/on_deploy"
        end
      end
    end
end
