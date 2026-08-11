module Kamal::Cli::App::CounterpartVersion
  private
    # The version running in the other slot — rollout when booting live, live when
    # booting a rollout. Its assets must survive both the sync and the clean up.
    def counterpart_versions
      return [] unless (counterpart = role.counterpart)

      version = capture_with_info(
        *KAMAL.app(role: counterpart, host: host).current_running_version,
        raise_on_non_zero_exit: false
      ).strip.presence

      Array(version)
    end
end
