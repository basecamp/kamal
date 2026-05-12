class Kamal::Output::OtelLogger < Kamal::Output::BaseLogger
  def self.build(settings:, config:)
    raise ArgumentError, "OTel endpoint is required" unless settings["endpoint"]
    new(
      endpoint: settings["endpoint"],
      tags: Kamal::Tags.from_config(config).except(:service_version, :recorded_at),
      service: config.service
    )
  end

  def initialize(endpoint:, tags:, service: nil)
    @endpoint = endpoint
    @shipper = Kamal::OtelShipper.new(endpoint: endpoint, tags: tags)
    @service = service
    super()
  end

  def <<(message)
    host = Thread.current[:kamal_host]
    iostream = Thread.current[:kamal_iostream]
    severity = Thread.current[:kamal_severity]
    @shipper.append(message, host: host, iostream: iostream, severity: severity)
  end

  DEPLOY_COMMANDS = %w[ deploy redeploy rollback setup ].freeze

  private
    def on_start(payload)
      @shipper.event("kamal.start",
        "kamal.command": full_command(payload),
        **deployment_attrs(payload))
    end

    def on_finish(payload, runtime)
      if payload[:exception]
        error_class, error_message = payload[:exception]
        @shipper.event("kamal.failed", severity: :error,
          "kamal.command": full_command(payload), "kamal.runtime": runtime,
          "exception.type": error_class, "exception.message": error_message,
          **deployment_attrs(payload, status: "failed"))
      else
        @shipper.event("kamal.complete",
          "kamal.command": full_command(payload), "kamal.runtime": runtime,
          **deployment_attrs(payload, status: "succeeded"))
      end
      puts "Logs sent to #{@endpoint}"
    end

    def on_close
      @shipper.shutdown
    end

    def full_command(payload)
      [ payload[:command], payload[:subcommand] ].compact.join(" ")
    end

    def deploy?(payload)
      DEPLOY_COMMANDS.include?(payload[:command])
    end

    def deployment_attrs(payload, status: nil)
      if deploy?(payload)
        attrs = { "deployment.id": @shipper.run_id, "deployment.name": "#{full_command(payload)} #{@service}" }
        attrs[:"deployment.status"] = status if status
        attrs
      else
        {}
      end
    end
end
