module Kamal::Commands::App::Execution
  def execute_in_existing_container(*command, interactive: false, env:)
    docker :exec,
      ("-it" if interactive),
      *argumentize("--env", env),
      container_name,
      *command
  end

  def execute_in_new_container(*command, interactive: false, env:)
    docker :run,
      ("-it" if interactive),
      "--rm",
      "--network", "kamal",
      *role&.env_args(host),
      *argumentize("--env", env),
      *config.volume_args,
      *role&.option_args,
      config.absolute_image,
      *command
  end

  def execute_in_existing_container_over_ssh(*command,  env:)
    run_over_ssh execute_in_existing_container(*command, interactive: true, env: env), host: host
  end

  def execute_in_new_container_over_ssh(*command, env:)
    run_over_ssh execute_in_new_container(*command, interactive: true, env: env), host: host
  end
end
