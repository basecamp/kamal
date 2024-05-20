require "tempfile"

class Kamal::Cli::Env < Kamal::Cli::Base
  desc "push", "Push the env file to the remote hosts"
  def push
    with_lock do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Pushed env files"), verbosity: :debug

        KAMAL.roles_on(host).each do |role|
          execute *KAMAL.app(role: role, host: host).make_env_directory
          upload! role.env(host).secrets_io, role.env(host).secrets_file, mode: 400
        end
      end

      on(KAMAL.traefik_hosts) do
        execute *KAMAL.traefik.make_env_directory
        upload! KAMAL.traefik.env.secrets_io, KAMAL.traefik.env.secrets_file, mode: 400
      end

      on(KAMAL.accessory_hosts) do
        KAMAL.accessories_on(host).each do |accessory|
          accessory_config = KAMAL.config.accessory(accessory)
          execute *KAMAL.accessory(accessory).make_env_directory
          upload! accessory_config.env.secrets_io, accessory_config.env.secrets_file, mode: 400
        end
      end
    end
  end

  desc "delete", "Delete the env file from the remote hosts"
  def delete
    with_lock do
      on(KAMAL.hosts) do
        execute *KAMAL.auditor.record("Deleted env files"), verbosity: :debug

        KAMAL.roles_on(host).each do |role|
          execute *KAMAL.app(role: role, host: host).remove_env_file
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
