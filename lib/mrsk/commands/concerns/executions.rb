module Mrsk::Commands::Concerns::Executions
  def execute_in_existing_container(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      config.service_with_version,
      *command
  end

  def execute_in_new_container(*command, interactive: false)
    docker :run,
      ("-it" if interactive),
      "--rm",
      *rails_master_key_arg,
      *config.env_args,
      *config.volume_args,
      config.absolute_image,
      *command
  end

  def execute_in_existing_container_over_ssh(*command, host:)
    run_over_ssh execute_in_existing_container(*command, interactive: true).join(" "), host: host
  end

  def execute_in_new_container_over_ssh(*command, host:)
    run_over_ssh execute_in_new_container(*command, interactive: true).join(" "), host: host
  end
end
