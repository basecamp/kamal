module Kamal::Commands::App::Proxy
  delegate :container_name, to: :"config.proxy_boot", prefix: :proxy

  def deploy(target:)
    proxy_exec :deploy, role.container_prefix, *role.proxy.deploy_command_args(target: target)
  end

  def remove
    proxy_exec :remove, role.container_prefix
  end

  def live
    proxy_exec :resume, role.container_prefix
  end

  def maintenance(**options)
    proxy_exec :stop, role.container_prefix, *role.proxy.stop_command_args(**options)
  end

  def remove_proxy_app_directory
    remove_directory config.proxy_boot.app_directory
  end

  def health_check_response(target:)
    health_check_path = role.proxy.proxy_config.dig("healthcheck", "path") || "/up"
    app_port = role.proxy.app_port

    pipe \
      docker(:inspect, "--format", "'{{.NetworkSettings.Networks.kamal.IPAddress}}'", target),
      [ :xargs, "-I{}", :curl, "-s", "-o", "-", "-w", "'\\n%{http_code}'", "--max-time", "5",
        "http://{}:#{app_port}#{health_check_path}" ]
  end

  def create_ssl_directory
    make_directory(File.join(config.proxy_boot.tls_directory, role.name))
  end

  private
    def proxy_exec(*command)
      docker :exec, proxy_container_name, "kamal-proxy", *command
    end
end
