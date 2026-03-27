require "logger"

class Kamal::Output::BaseLogger < ::Logger
  def initialize
    super(nil)
    @subscription = ActiveSupport::Notifications.subscribe("modify.kamal", self)
  end

  def start(name, id, payload)
    @started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    on_start(payload)
  end

  def finish(name, id, payload)
    runtime = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started_at).round(1)
    on_finish(payload, runtime)
  end

  def add(severity, message = nil, progname = nil, &block)
    if msg = message || (block ? block.call : progname)
      self << msg.to_s
    end
  end

  def close
    ActiveSupport::Notifications.unsubscribe(@subscription)
    on_close
  end
end
