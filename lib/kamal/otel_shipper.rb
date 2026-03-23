require "active_support/core_ext/numeric/time"
require "net/http"
require "json"
require "uri"

class Kamal::OtelShipper
  BATCH_SIZE = 100
  FLUSH_INTERVAL = 5.seconds

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
    str.to_s.each_line do |line|
      @buffer << line.chomp
    end

    self
  end

  def event(name, **attributes)
    attrs = attributes.map { |k, v| { key: k.to_s, value: { stringValue: v.to_s } } }
    @buffer << { body: name, attributes: attrs }

    self
  end

  def flush
    @flush_mutex.synchronize do
      lines = drain_buffer
      ship(lines) if lines.any?
    end
  end

  def shutdown
    @running = false
    @thread&.join(FLUSH_INTERVAL + 1.second)
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
      until @buffer.empty?
        lines << @buffer.pop(true)
      end
      lines
    rescue ThreadError
      lines
    end

    def ship(items)
      items.each_slice(BATCH_SIZE) do |batch|
        records = batch.map do |item|
          record = {
            timeUnixNano: time_ns,
            severityNumber: 9,
            severityText: "INFO"
          }

          if item.is_a?(Hash)
            record[:body] = { stringValue: item[:body] }
            record[:attributes] = item[:attributes]
          else
            record[:body] = { stringValue: item }
          end

          record
        end
        ship_records(records)
      end
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
      http.open_timeout = 2.seconds
      http.read_timeout = 5.seconds
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
