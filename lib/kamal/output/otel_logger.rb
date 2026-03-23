require "logger"

class Kamal::Output::OtelLogger < ::Logger
  def initialize(endpoint:, tags:)
    @shipper = Kamal::OtelShipper.new(endpoint: endpoint, tags: tags)

    super(nil)

    subscribe
  end

  def add(severity, message = nil, progname = nil, &block)
    msg = message || (block ? block.call : progname)
    @shipper << msg.to_s if msg
  end

  def close
    unsubscribe
    @shipper.shutdown
  end

  private
    def subscribe
      @subscription = ActiveSupport::Notifications.subscribe("modify.kamal") do |event|
        if event.payload[:exception]
          error_class, error_message = event.payload[:exception]
          @shipper.event("deploy.failed",
            command: event.payload[:command].to_s,
            error: "#{error_class}: #{error_message}")
        else
          @shipper.event("deploy.complete",
            command: event.payload[:command].to_s,
            runtime: event.duration.round.to_s)
        end
      end

      @start_subscription = ActiveSupport::Notifications.subscribe("start_modify.kamal") do |event|
        @shipper.event("deploy.start",
          command: event.payload[:command].to_s,
          hosts: event.payload[:hosts].to_s)
      end
    end

    def unsubscribe
      ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
      ActiveSupport::Notifications.unsubscribe(@start_subscription) if @start_subscription
    end
end
