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
    ssl = proxy.proxy_config["ssl"]

    cert_content = require_secret!(
      content: proxy.certificate_pem_content,
      secret_key: ssl["certificate_pem"],
      config_key: "certificate_pem"
    )
    key_content = require_secret!(
      content: proxy.private_key_pem_content,
      secret_key: ssl["private_key_pem"],
      config_key: "private_key_pem"
    )

    info "Writing SSL certificates for accessory #{accessory.name}"
    execute *accessory.create_ssl_directory

    upload!(StringIO.new(cert_content), proxy.host_tls_cert, mode: "0644")
    upload!(StringIO.new(key_content), proxy.host_tls_key, mode: "0644")
  end

  private
    def require_secret!(content:, secret_key:, config_key:)
      return content if content.present?

      raise ArgumentError,
        "Missing SSL secret #{secret_key.inspect} " \
        "for accessory #{accessory.name.inspect} (#{config_key})"
    end
end
