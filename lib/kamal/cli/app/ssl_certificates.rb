class Kamal::Cli::App::SslCertificates
  attr_reader :host, :role, :sshkit
  delegate :execute, :info, to: :sshkit

  def initialize(host, role, sshkit)
    @host = host
    @role = role
    @sshkit = sshkit
  end

  def run
    if role.running_proxy? && role.proxy.custom_ssl_certificate?
      info "Writing SSL certificates for #{role.name} on #{host}"
      execute *app.create_ssl_directory
      if cert_content = role.proxy.certificate_pem_content
        execute *app.write_certificate_file(cert_content)
      end
      if key_content = role.proxy.private_key_pem_content
        execute *app.write_private_key_file(key_content)
      end
    end
  end

  private
    def app
      @app ||= KAMAL.app(role: role, host: host)
    end
end
