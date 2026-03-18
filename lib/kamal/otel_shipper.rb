require "net/http"
require "json"
require "uri"

class Kamal::OtelShipper
  BATCH_SIZE = 100
  FLUSH_INTERVAL = 5 # seconds

  def initialize(endpoint:, service_namespace:, environment:, version:, performer: nil)
    @endpoint = URI("#{endpoint}/v1/logs")
    @service_namespace = service_namespace
    @environment = environment || "unknown"
    @version = version
    @performer = performer || ENV["USER"] || "unknown"
    @buffer = Queue.new
    @flush_mutex = Mutex.new
    @running = true
    @thread = start_flush_thread
  end

  def <<(str)
    return self unless @running
    str.to_s.each_line do |line|
      stripped = line.chomp
      @buffer << stripped unless stripped.empty?
    end
    flush if @buffer.size >= BATCH_SIZE
    self
  end

  def event(name, **attributes)
    attrs = attributes.map { |k, v| { key: k.to_s, value: { stringValue: v.to_s } } }
    records = [ {
      timeUnixNano: time_ns,
      severityNumber: 9,
      severityText: "INFO",
      body: { stringValue: name },
      attributes: attrs
    } ]
    ship_records(records)
  end

  def flush
    @flush_mutex.synchronize do
      lines = drain_buffer
      return if lines.empty?

      lines.each_slice(BATCH_SIZE) { |batch| ship_lines(batch) }
    end
  end

  def shutdown
    @running = false
    @thread&.kill
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
      lines << @buffer.pop(true) until @buffer.empty?
      lines
    rescue ThreadError
      lines
    end

    def ship_lines(lines)
      records = lines.map do |line|
        {
          timeUnixNano: time_ns,
          severityNumber: 9,
          severityText: "INFO",
          body: { stringValue: line }
        }
      end
      ship_records(records)
    end

    def ship_records(records)
      payload = {
        resourceLogs: [ {
          resource: { attributes: resource_attributes },
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

    def resource_attributes
      [
        { key: "service.name", value: { stringValue: "kamal" } },
        { key: "service.namespace", value: { stringValue: @service_namespace } },
        { key: "service.version", value: { stringValue: @version } },
        { key: "deployment.environment.name", value: { stringValue: @environment } },
        { key: "deploy.performer", value: { stringValue: @performer } }
      ]
    end

    def time_ns
      (Time.now.to_f * 1_000_000_000).to_i.to_s
    end
end
