require "tempfile"

class Kamal::Cli::Env < Kamal::Cli::Base
  desc "push", "Push the env file to the remote hosts"
  def push
    mutating do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Pushed env files"), verbosity: :debug

        KAMAL.roles_on(host).each do |role|
          execute *KAMAL.app(role: role).make_env_directory
          upload! StringIO.new(role.env_file), role.host_env_file_path, mode: 400
        end
      end

      on(KAMAL.traefik_hosts) do
        execute *KAMAL.traefik.make_env_directory
        upload! StringIO.new(KAMAL.traefik.env_file), KAMAL.traefik.host_env_file_path, mode: 400
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
        execute *KAMAL.auditor.record("Deleted env files"), verbosity: :debug

        KAMAL.roles_on(host).each do |role|
          execute *KAMAL.app(role: role).remove_env_file
        end
      end

      on(KAMAL.traefik_hosts) do
        execute *KAMAL.traefik.remove_env_file
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
