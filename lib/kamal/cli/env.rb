require "tempfile"

class Kamal::Cli::Env < Kamal::Cli::Base
  desc "push", "Push the env file to the remote hosts"
  def push
    mutating do
      on(KAMAL.hosts) do
        KAMAL.roles_on(host).each do |role|
          role_config = KAMAL.config.role(role)
          execute *KAMAL.app(role: role).make_env_directory
          upload! StringIO.new(role_config.env_file), role_config.host_env_file_path, mode: 400
        end
      end

      on(KAMAL.traefik_hosts) do
        traefik_static_config = KAMAL.traefik_static.static_config
        execute *KAMAL.traefik_static.make_env_directory
        upload! StringIO.new(traefik_static_config.env_file), traefik_static_config.host_env_file_path, mode: 400
      end

      on(KAMAL.accessory_hosts) do
        KAMAL.accessories_on(host).each do |accessory|
          accessory_config = KAMAL.config.accessory(accessory)
          execute *KAMAL.accessory(accessory).make_env_directory
          upload! StringIO.new(accessory_config.env_file), accessory_config.host_env_file_path, mode: 400
        end
      end
    end
  end

  desc "delete", "Delete the env file from the remote hosts"
  def delete
    mutating do
      on(KAMAL.hosts) do
        KAMAL.roles_on(host).each do |role|
          role_config = KAMAL.config.role(role)
          execute *KAMAL.app(role: role).remove_env_file
        end
      end

      on(KAMAL.traefik_hosts) do
        execute *KAMAL.traefik_static.remove_env_file
      end

      on(KAMAL.accessory_hosts) do
        KAMAL.accessories_on(host).each do |accessory|
          accessory_config = KAMAL.config.accessory(accessory)
          execute *KAMAL.accessory(accessory).remove_env_file
        end
      end
    end
  end
end
