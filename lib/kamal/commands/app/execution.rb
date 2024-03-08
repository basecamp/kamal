module Kamal::Commands::App::Execution
  def execute_in_existing_container(*command, interactive: false)
    docker :exec,
      ("-it" if interactive),
      container_name,
      *command
  end

  def execute_in_new_container(*command, interactive: false)
    docker :run,
      ("-it" if interactive),
      "--rm",
      *role&.env_args,
      *config.volume_args,
      *role&.option_args,
      config.absolute_image,
      *command
  end

  def execute_in_existing_container_over_ssh(*command, host:)
    run_over_ssh execute_in_existing_container(*command, interactive: true), host: host
  end

  def execute_in_new_container_over_ssh(*command, host:)
    run_over_ssh execute_in_new_container(*command, interactive: true), host: host
  end
end
