class Kamal::Utils::SwitchPoller
  class SwitchError < StandardError; end

  class << self
    TRAEFIK_SWITCH_DELAY = 2
    def wait_for_switch(traefik_dynamic, &block)
      if traefik_dynamic.boot_check?
        Kamal::Utils.poll(max_attempts: 5, exception: SwitchError) do
          polled_run_id = block.call
          raise SwitchError, "Waiting for #{traefik_dynamic.config_run_id}, currently #{polled_run_id}" unless polled_run_id == traefik_dynamic.config_run_id
        end
      else
        sleep TRAEFIK_SWITCH_DELAY
      end
    end
  end
end
