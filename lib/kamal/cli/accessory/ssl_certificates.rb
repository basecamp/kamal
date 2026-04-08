class Kamal::Cli::Accessory::SslCertificates
  attr_reader :accessory, :sshkit
  delegate :execute, :info, :upload!, to: :sshkit

  def initialize(accessory, sshkit)
    @accessory = accessory
    @sshkit = sshkit
  end

  def run
    return unless accessory.running_proxy? && accessory.proxy.custom_ssl_certificate?

    proxy = accessory.proxy

    info "Writing SSL certificates for accessory #{accessory.name}"
    execute *accessory.create_ssl_directory

    if (cert_content = proxy.certificate_pem_content)
      upload!(StringIO.new(cert_content), proxy.host_tls_cert, mode: "0644")
    end
    if (key_content = proxy.private_key_pem_content)
      upload!(StringIO.new(key_content), proxy.host_tls_key, mode: "0644")
    end
  end
end
