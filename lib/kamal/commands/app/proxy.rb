module Kamal::Commands::App::Proxy
  def deploy(target:)
    proxy_exec :deploy, role.container_prefix, *role.proxy.deploy_command_args(target: target)
  end

  def remove
    proxy_exec :remove, role.container_prefix
  end

  private
    def proxy_exec(*command)
      docker :exec, config.proxy.container_name, "kamal-proxy", *command
    end
end
