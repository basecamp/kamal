module Kamal::Commands::Accessory::Proxy
  delegate :proxy, to: :config

  def deploy(target:)
    proxy_exec :deploy, service_name, *proxy.deploy_command_args(target: target)
  end

  def remove
    proxy_exec :remove, service_name
  end

  private
    def proxy_exec(*command)
      docker :exec, proxy.container_name, "kamal-proxy", *command
    end
end
