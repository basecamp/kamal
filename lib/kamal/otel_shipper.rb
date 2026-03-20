require "net/http"
require "json"
require "uri"

class Kamal::OtelShipper
  BATCH_SIZE = 100
  FLUSH_INTERVAL = 5 # seconds

  OTEL_ATTRIBUTE_KEYS = {
    service: "service.name",
    service_version: "service.version",
    performer: "deploy.performer",
    destination: "deployment.environment.name",
    recorded_at: "deploy.recorded_at",
    version: "deploy.version"
  }

  def initialize(endpoint:, tags:)
    @endpoint = URI("#{endpoint}/v1/logs")
    @resource_attributes = tags.tags.map do |key, value|
      otel_key = OTEL_ATTRIBUTE_KEYS.fetch(key, "kamal.#{key}")
      { key: otel_key, value: { stringValue: value.to_s } }
    end
    @buffer = Queue.new
    @flush_mutex = Mutex.new
    @running = true
    @thread = start_flush_thread
  end

  def <<(str)
    return self unless @running
    str.to_s.each_line do |line|
      stripped = line.chomp
      @buffer << stripped
    end
    self
  end

  def event(name, **attributes)
    attrs = attributes.map { |k, v| { key: k.to_s, value: { stringValue: v.to_s } } }
    @buffer << { event: name, attributes: attrs }
    self
  end

  def flush
    @flush_mutex.synchronize do
      lines, events = drain_buffer
      ship_lines(lines) if lines.any?
      ship_events(events) if events.any?
    end
  end

  def shutdown
    @running = false
    @thread&.join(FLUSH_INTERVAL + 1)
    flush
  end

  private
    def start_flush_thread
      Thread.new do
        while @running
          sleep FLUSH_INTERVAL
          flush
        end
      end
    end

    def drain_buffer
      lines = []
      events = []
      until @buffer.empty?
        item = @buffer.pop(true)
        if item.is_a?(Hash)
          events << item
        else
          lines << item
        end
      end
      [ lines, events ]
    rescue ThreadError
      [ lines, events ]
    end

    def ship_lines(lines)
      lines.each_slice(BATCH_SIZE) do |batch|
        records = batch.map do |line|
          {
            timeUnixNano: time_ns,
            severityNumber: 9,
            severityText: "INFO",
            body: { stringValue: line }
          }
        end
        ship_records(records)
      end
    end

    def ship_events(events)
      records = events.map do |event|
        {
          timeUnixNano: time_ns,
          severityNumber: 9,
          severityText: "INFO",
          body: { stringValue: event[:event] },
          attributes: event[:attributes]
        }
      end
      ship_records(records)
    end

    def ship_records(records)
      payload = {
        resourceLogs: [ {
          resource: { attributes: @resource_attributes },
          scopeLogs: [ { logRecords: records } ]
        } ]
      }

      http = Net::HTTP.new(@endpoint.host, @endpoint.port)
      http.use_ssl = @endpoint.scheme == "https"
      http.open_timeout = 2
      http.read_timeout = 5
      req = Net::HTTP::Post.new(@endpoint.path, "Content-Type" => "application/json")
      req.body = JSON.generate(payload)
      http.request(req)
    rescue
      # Best effort — never fail the deploy
    end

    def time_ns
      Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond).to_s
    end
end
