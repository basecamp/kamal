require "test_helper"

class OtelShipperTest < ActiveSupport::TestCase
  setup do
    @tags = Kamal::Tags.new(
      performer: "deployer",
      service: "myapp",
      version: "abc123",
      destination: "production"
    )
    Kamal::OtelShipper.any_instance.stubs(:start_flush_thread)
    @shipper = Kamal::OtelShipper.new(endpoint: "http://localhost:4318", tags: @tags)
  end

  teardown do
    @shipper.shutdown
  end

  test "appends log lines to buffer as OTLP records" do
    @shipper << "hello world"
    @shipper << "second line"

    bodies = drain_buffer.map { |r| r[:body][:stringValue] }
    assert_equal [ "hello world", "second line" ], bodies
  end

  test "splits multi-line strings into separate records" do
    @shipper << "line one\nline two\nline three\n"

    bodies = drain_buffer.map { |r| r[:body][:stringValue] }
    assert_equal [ "line one", "line two", "line three" ], bodies
  end

  test "preserves empty lines" do
    @shipper << "before\n\nafter\n"

    bodies = drain_buffer.map { |r| r[:body][:stringValue] }
    assert_equal [ "before", "", "after" ], bodies
  end

  test "event buffers structured data as OTLP record" do
    @shipper.event("kamal.start", "kamal.deploy_version": "abc123")

    record = drain_buffer.first
    assert_equal "kamal.start", record[:body][:stringValue]
    assert_equal "kamal.start", record[:eventName]
    assert_not_nil record[:observedTimeUnixNano]

    attr_keys = record[:attributes].map { |a| a[:key] }
    assert_includes attr_keys, "kamal.deploy_version"
  end

  test "append includes server.address and log.iostream attributes" do
    @shipper.append("output line", host: "1.1.1.1", iostream: "stdout")

    record = drain_buffer.first
    attrs = record[:attributes]

    host_attr = attrs.find { |a| a[:key] == "server.address" }
    assert_equal "1.1.1.1", host_attr[:value][:stringValue]

    iostream_attr = attrs.find { |a| a[:key] == "log.iostream" }
    assert_equal "stdout", iostream_attr[:value][:stringValue]
  end

  test "append maps Logger severity to OTel severity" do
    @shipper.append("debug line", severity: Logger::DEBUG)
    @shipper.append("info line", severity: Logger::INFO)
    @shipper.append("warn line", severity: Logger::WARN)

    records = drain_buffer
    assert_equal 5, records[0][:severityNumber]
    assert_equal "DEBUG", records[0][:severityText]
    assert_equal 9, records[1][:severityNumber]
    assert_equal "INFO", records[1][:severityText]
    assert_equal 13, records[2][:severityNumber]
    assert_equal "WARN", records[2][:severityText]
  end

  test "append defaults to INFO when no severity given" do
    @shipper.append("plain line")

    record = drain_buffer.first
    assert_equal 9, record[:severityNumber]
  end

  test "append without host or iostream omits context attributes" do
    @shipper.append("plain line")

    record = drain_buffer.first
    assert_nil record[:attributes]
  end

  test "records have no attributes when appended without context" do
    @shipper << "line"

    record = drain_buffer.first
    assert_nil record[:attributes]
  end

  test "event defaults to INFO severity" do
    @shipper.event("kamal.start", "kamal.command": "deploy")

    record = drain_buffer.first
    assert_equal 9, record[:severityNumber]
    assert_equal "INFO", record[:severityText]
  end

  test "event supports ERROR severity" do
    @shipper.event("kamal.failed", severity: :error, "kamal.command": "deploy")

    record = drain_buffer.first
    assert_equal 17, record[:severityNumber]
    assert_equal "ERROR", record[:severityText]
  end

  test "event attributes preserve numeric types" do
    @shipper.event("kamal.complete", "kamal.runtime": 1.5, retries: 3)

    record = drain_buffer.first
    runtime = record[:attributes].find { |a| a[:key] == "kamal.runtime" }
    assert_equal({ doubleValue: 1.5 }, runtime[:value])
    retries = record[:attributes].find { |a| a[:key] == "retries" }
    assert_equal({ intValue: 3 }, retries[:value])
  end

  test "event attributes support arrays" do
    @shipper.event("kamal.start", hosts: [ "1.1.1.1", "2.2.2.2" ])

    record = drain_buffer.first
    hosts = record[:attributes].find { |a| a[:key] == "hosts" }
    assert_equal({ arrayValue: { values: [ { stringValue: "1.1.1.1" }, { stringValue: "2.2.2.2" } ] } }, hosts[:value])
  end

  test "flush ships buffered lines via HTTP" do
    @shipper << "test log line"
    stub_otel_http

    @shipper.flush

    assert_equal 1, shipped_records.length
    assert_equal "test log line", shipped_records.first.dig("body", "stringValue")
  end

  test "flush ships events with eventName and OTLP attributes" do
    @shipper.event("kamal.complete", status: "success")
    stub_otel_http

    @shipper.flush

    record = shipped_records.first
    assert_equal "kamal.complete", record.dig("body", "stringValue")
    assert_equal "kamal.complete", record["eventName"]
    status = record["attributes"].find { |a| a["key"] == "status" }
    assert_equal "success", status.dig("value", "stringValue")
  end

  test "resource attributes use OTel semantic convention keys" do
    @shipper << "line"
    stub_otel_http

    @shipper.flush

    keys = shipped_resource_attrs.map { |a| a["key"] }
    assert_includes keys, "service.name"
    assert_includes keys, "service.namespace"
    assert_includes keys, "service.version"
    assert_includes keys, "kamal.run_id"
    assert_includes keys, "kamal.deploy_version"
    assert_includes keys, "kamal.performer"
    assert_includes keys, "deployment.environment.name"

    assert_equal "kamal", shipped_resource_attr("service.name")
    assert_equal Kamal::VERSION, shipped_resource_attr("service.version")
    assert_equal "myapp", shipped_resource_attr("service.namespace")
    assert_equal @shipper.run_id, shipped_resource_attr("kamal.run_id")
    assert_equal "abc123", shipped_resource_attr("kamal.deploy_version")
    assert_equal "deployer", shipped_resource_attr("kamal.performer")
  end

  test "instrumentation scope identifies kamal" do
    @shipper << "line"
    stub_otel_http

    @shipper.flush

    scope = @shipped.first.dig("resourceLogs", 0, "scopeLogs", 0, "scope")
    assert_equal "kamal", scope["name"]
    assert_equal Kamal::VERSION, scope["version"]
  end

  test "accepts lines after shutdown" do
    @shipper.shutdown
    @shipper << "still works"

    bodies = drain_buffer.map { |r| r[:body][:stringValue] }
    assert_equal [ "still works" ], bodies
  end

  test "HTTP errors are swallowed and first failure logged to stderr" do
    @shipper << "line"
    Net::HTTP.any_instance.stubs(:start).raises(Errno::ECONNREFUSED)

    stderr_output = capture_io { @shipper.flush }[1]
    assert_match /OTel log shipping failed/, stderr_output

    # Second failure is silent
    @shipper << "another line"
    stderr_output = capture_io { @shipper.flush }[1]
    assert_empty stderr_output
  end

  test "flush thread ships buffered lines automatically" do
    shipped = Queue.new
    threaded_shipper = create_threaded_shipper

    # Override flush to capture calls without HTTP
    threaded_shipper.define_singleton_method(:flush) do
      @flush_mutex.synchronize do
        records = send(:drain_buffer)
        shipped << records if records.any?
      end
    end

    threaded_shipper << "threaded line"

    # Wake the flush thread immediately
    threaded_shipper.instance_variable_get(:@signal) << true

    records = shipped.pop(timeout: 5)
    assert_not_nil records, "Expected flush thread to ship within timeout"
    bodies = records.map { |r| r[:body][:stringValue] }
    assert_includes bodies, "threaded line"
  ensure
    threaded_shipper&.instance_variable_set(:@running, false)
    threaded_shipper&.instance_variable_get(:@signal)&.push(true)
    threaded_shipper&.instance_variable_get(:@thread)&.join(1)
  end

  test "shutdown flushes remaining lines" do
    stub_otel_http

    threaded_shipper = create_threaded_shipper
    threaded_shipper << "final line"
    threaded_shipper.shutdown

    bodies = @shipped.flat_map { |b| b.dig("resourceLogs", 0, "scopeLogs", 0, "logRecords") }
      .map { |r| r.dig("body", "stringValue") }
    assert_includes bodies, "final line"
  end

  private
    def drain_buffer
      @shipper.send(:drain_buffer)
    end

    def create_threaded_shipper
      Kamal::OtelShipper.any_instance.unstub(:start_flush_thread)
      Kamal::OtelShipper.new(endpoint: "http://localhost:4318", tags: @tags)
    end

    def stub_otel_http
      @shipped = []
      http = stub("http")
      http.stubs(:request).with do |req|
        @shipped << JSON.parse(req.body)
        true
      end.returns(Net::HTTPOK.new("1.1", "200", "OK"))
      Net::HTTP.any_instance.stubs(:start).yields(http)
    end

    def shipped_records
      @shipped.flat_map { |b| b.dig("resourceLogs", 0, "scopeLogs", 0, "logRecords") }
    end

    def shipped_resource_attrs
      @shipped.first.dig("resourceLogs", 0, "resource", "attributes")
    end

    def shipped_resource_attr(key)
      shipped_resource_attrs.find { |a| a["key"] == key }.dig("value", "stringValue")
    end
end
