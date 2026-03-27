require "active_support/core_ext/numeric/time"
require "net/http"
require "json"
require "securerandom"
require "uri"

class Kamal::OtelShipper
  BATCH_SIZE = 100
  FLUSH_INTERVAL = 5.seconds

  OTEL_ATTRIBUTE_KEYS = {
    service: "service.namespace",
    version: "kamal.deploy_version",
    performer: "kamal.performer",
    destination: "deployment.environment.name"
  }

  SEVERITIES = {
    debug: { severityNumber: 5,  severityText: "DEBUG" },
    info:  { severityNumber: 9,  severityText: "INFO" },
    warn:  { severityNumber: 13, severityText: "WARN" },
    error: { severityNumber: 17, severityText: "ERROR" },
    fatal: { severityNumber: 21, severityText: "FATAL" }
  }

  LOGGER_SEVERITIES = {
    Logger::DEBUG => :debug,
    Logger::INFO  => :info,
    Logger::WARN  => :warn,
    Logger::ERROR => :error,
    Logger::FATAL => :fatal
  }

  attr_reader :run_id

  def initialize(endpoint:, tags:)
    @endpoint = URI("#{endpoint.chomp('/')}/v1/logs")
    @run_id = SecureRandom.uuid
    @resource_attributes = [
      { key: "service.name", value: { stringValue: "kamal" } },
      { key: "service.version", value: { stringValue: Kamal::VERSION } },
      { key: "kamal.run_id", value: { stringValue: @run_id } },
      *tags.tags.map do |key, value|
        otel_key = OTEL_ATTRIBUTE_KEYS.fetch(key, "kamal.#{key}")
        { key: otel_key, value: { stringValue: value.to_s } }
      end
    ]
    @buffer = Queue.new
    @flush_mutex = Mutex.new
    @running = true
    @signal = Queue.new
    @thread = start_flush_thread
  end

  def <<(str)
    append(str)
  end

  def append(str, host: nil, iostream: nil, severity: nil)
    otel_severity = LOGGER_SEVERITIES.fetch(severity, :info)
    extra = build_context_attributes(host: host, iostream: iostream)
    str.to_s.each_line do |line|
      enqueue build_record(line.chomp, severity: otel_severity, attributes: extra)
    end

    self
  end

  def event(name, severity: :info, **attributes)
    attrs = attributes.map { |k, v| { key: k.to_s, value: typed_value(v) } }
    enqueue build_record(name, severity: severity, event_name: name, attributes: attrs)

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
    @signal << true
    @thread&.join(FLUSH_INTERVAL + 1.second)
    flush
  end

  private
    def enqueue(record)
      @buffer << record
      @signal << true if @buffer.size >= BATCH_SIZE
    end

    def start_flush_thread
      Thread.new do
        while @running
          @signal.pop(timeout: FLUSH_INTERVAL)
          flush
        end
      end
    end

    def drain_buffer
      records = []
      records << @buffer.pop(true) until @buffer.empty?
      records
    end

    def ship(records)
      with_connection do |http|
        records.each_slice(BATCH_SIZE) do |batch|
          ship_records(http, batch)
        end
      end
    end

    def build_record(body, severity: :info, event_name: nil, attributes: nil)
      now = time_ns
      { timeUnixNano: now, observedTimeUnixNano: now, **SEVERITIES.fetch(severity),
        body: { stringValue: body }, eventName: event_name, attributes: attributes }.compact
    end

    def build_context_attributes(host:, iostream:)
      attrs = []
      attrs << { key: "server.address", value: { stringValue: host } } if host
      attrs << { key: "log.iostream", value: { stringValue: iostream } } if iostream
      attrs.presence
    end

    def typed_value(v)
      case v
      when Integer then { intValue: v }
      when Float   then { doubleValue: v }
      when Array   then { arrayValue: { values: v.map { |e| typed_value(e) } } }
      else              { stringValue: v.to_s }
      end
    end

    def with_connection
      http = Net::HTTP.new(@endpoint.host, @endpoint.port)
      http.use_ssl = @endpoint.scheme == "https"
      http.open_timeout = 2.seconds
      http.read_timeout = 5.seconds
      http.start { |conn| yield conn }
    rescue StandardError => e
      unless @ship_error_logged
        @ship_error_logged = true
        $stderr.puts "OTel log shipping failed: #{e.class}: #{e.message}"
        $stderr.puts e.backtrace.join("\n") if ENV["VERBOSE"]
      end
    end

    def ship_records(http, records)
      payload = {
        resourceLogs: [ {
          resource: { attributes: @resource_attributes },
          scopeLogs: [ { scope: { name: "kamal", version: Kamal::VERSION }, logRecords: records } ]
        } ]
      }

      req = Net::HTTP::Post.new(@endpoint.request_uri, "Content-Type" => "application/json")
      req.body = JSON.generate(payload)
      response = http.request(req)

      unless response.is_a?(Net::HTTPSuccess) || @ship_error_logged
        @ship_error_logged = true
        $stderr.puts "OTel log shipping failed: HTTP #{response.code} #{response.message}"
      end
    end

    def time_ns
      Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond).to_s
    end
end
