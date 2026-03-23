require "logger"

class Kamal::Output::FileLogger < ::Logger
  def initialize(path:)
    @path = Pathname.new(path)
    @file = nil

    super(nil)

    @subscription = ActiveSupport::Notifications.subscribe("modify.kamal", self)
  end

  def start(name, id, payload)
    @path.mkpath
    filename = "#{Time.now.strftime('%Y-%m-%dT%H-%M-%S')}_#{payload[:command]}.log"
    @file = File.open(@path.join(filename), "a")
  end

  def finish(name, id, payload)
    if payload[:exception]
      error_class, error_message = payload[:exception]
      @file&.puts "# FAILED: #{error_class}: #{error_message}"
    else
      @file&.puts "# Completed"
    end
    @file&.close
    @file = nil
  end

  def add(severity, message = nil, progname = nil, &block)
    return unless @file
    msg = message || (block ? block.call : progname)
    @file.puts(msg.to_s) if msg
    @file.flush
  end

  def close
    ActiveSupport::Notifications.unsubscribe(@subscription)
    @file&.close
    @file = nil
  end
end
