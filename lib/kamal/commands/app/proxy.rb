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

  def create_ssl_directory
    make_directory(config.proxy_boot.tls_directory)
  end

  def write_certificate_file(content)
    [ :sh, "-c", Kamal::Utils.sensitive("cat > #{config.proxy_boot.tls_directory}/cert.pem << 'KAMAL_CERT_EOF'\n#{content}\nKAMAL_CERT_EOF", redaction: "cat > #{config.proxy_boot.tls_directory}/cert.pem << 'KAMAL_CERT_EOF'\n[CERTIFICATE CONTENT REDACTED]\nKAMAL_CERT_EOF") ]
  end

  def write_private_key_file(content)
    [ :sh, "-c", Kamal::Utils.sensitive("cat > #{config.proxy_boot.tls_directory}/key.pem << 'KAMAL_KEY_EOF'\n#{content}\nKAMAL_KEY_EOF", redaction: "cat > #{config.proxy_boot.tls_directory}/key.pem << 'KAMAL_KEY_EOF'\n[PRIVATE KEY CONTENT REDACTED]\nKAMAL_KEY_EOF") ]
  end

  private
    def proxy_exec(*command)
      docker :exec, proxy_container_name, "kamal-proxy", *command
    end
end
