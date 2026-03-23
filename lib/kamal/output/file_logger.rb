require "logger"
require "fileutils"

class Kamal::Output::FileLogger < ::Logger
  def initialize(path:)
    @path = Pathname.new(path)
    @file = nil

    super(nil)

    subscribe
  end

  def add(severity, message = nil, progname = nil, &block)
    return unless @file
    msg = message || (block ? block.call : progname)
    @file.puts(msg.to_s) if msg
    @file.flush
  end

  def close
    unsubscribe
    @file&.close
    @file = nil
  end

  private
    def subscribe
      @start_subscription = ActiveSupport::Notifications.subscribe("start_modify.kamal") do |event|
        open_log_file(event.payload[:command])
      end

      @subscription = ActiveSupport::Notifications.subscribe("modify.kamal") do |event|
        if event.payload[:exception]
          error_class, error_message = event.payload[:exception]
          @file&.puts "# FAILED: #{error_class}: #{error_message}"
        else
          @file&.puts "# Completed in #{event.duration.round(1)}s"
        end
        @file&.close
        @file = nil
      end
    end

    def unsubscribe
      ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
      ActiveSupport::Notifications.unsubscribe(@start_subscription) if @start_subscription
    end

    def open_log_file(command)
      @path.mkpath
      filename = "#{Time.now.strftime('%Y-%m-%dT%H-%M-%S')}_#{command}.log"
      @file = File.open(@path.join(filename), "a")
    end
end
