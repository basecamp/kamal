require "logger"

class Kamal::Output::OtelLogger < ::Logger
  def initialize(endpoint:, tags:)
    @shipper = Kamal::OtelShipper.new(endpoint: endpoint, tags: tags)

    super(nil)

    @subscription = ActiveSupport::Notifications.subscribe("modify.kamal", self)
  end

  def start(name, id, payload)
    @shipper.event("deploy.start",
      command: payload[:command].to_s,
      hosts: payload[:hosts].to_s)
  end

  def finish(name, id, payload)
    if payload[:exception]
      error_class, error_message = payload[:exception]
      @shipper.event("deploy.failed",
        command: payload[:command].to_s,
        error: "#{error_class}: #{error_message}")
    else
      @shipper.event("deploy.complete",
        command: payload[:command].to_s)
    end
  end

  def add(severity, message = nil, progname = nil, &block)
    msg = message || (block ? block.call : progname)
    @shipper << msg.to_s if msg
  end

  def close
    ActiveSupport::Notifications.unsubscribe(@subscription)
    @shipper.shutdown
  end
end
