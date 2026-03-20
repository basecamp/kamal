require "test_helper"

class OtelShipperTest < ActiveSupport::TestCase
  setup do
    @tags = Kamal::Tags.new(
      performer: "deployer",
      service: "myapp",
      version: "abc123",
      destination: "production"
    )
    @shipper = Kamal::OtelShipper.new(
      endpoint: "http://localhost:4318",
      tags: @tags
    )
  end

  teardown do
    @shipper.shutdown
  end

  test "appends log lines to buffer" do
    @shipper << "hello world"
    @shipper << "second line"

    lines, _events = @shipper.send(:drain_buffer)
    assert_equal [ "hello world", "second line" ], lines
  end

  test "splits multi-line strings into separate lines" do
    @shipper << "line one\nline two\nline three\n"

    lines, _events = @shipper.send(:drain_buffer)
    assert_equal [ "line one", "line two", "line three" ], lines
  end

  test "preserves empty lines" do
    @shipper << "before\n\nafter\n"

    lines, _events = @shipper.send(:drain_buffer)
    assert_equal [ "before", "", "after" ], lines
  end

  test "buffers events with attributes" do
    @shipper.event("deploy.start", version: "abc123", hosts: "1.1.1.1")

    _lines, events = @shipper.send(:drain_buffer)
    assert_equal 1, events.length
    assert_equal "deploy.start", events.first[:event]
    assert_equal 2, events.first[:attributes].length
  end

  test "flush ships buffered lines via HTTP" do
    @shipper << "test log line"

    request_body = nil
    stub_request = lambda do |req|
      request_body = JSON.parse(req.body)
      Net::HTTPOK.new("1.1", "200", "OK")
    end

    Net::HTTP.any_instance.stubs(:request).with { |req| stub_request.call(req) }

    @shipper.flush

    assert_not_nil request_body
    log_records = request_body.dig("resourceLogs", 0, "scopeLogs", 0, "logRecords")
    assert_equal 1, log_records.length
    assert_equal "test log line", log_records.first.dig("body", "stringValue")
  end

  test "flush ships events via HTTP" do
    @shipper.event("deploy.complete", status: "success")

    request_body = nil
    stub_request = lambda do |req|
      request_body = JSON.parse(req.body)
      Net::HTTPOK.new("1.1", "200", "OK")
    end

    Net::HTTP.any_instance.stubs(:request).with { |req| stub_request.call(req) }

    @shipper.flush

    assert_not_nil request_body
    log_records = request_body.dig("resourceLogs", 0, "scopeLogs", 0, "logRecords")
    assert_equal 1, log_records.length
    assert_equal "deploy.complete", log_records.first.dig("body", "stringValue")
    attrs = log_records.first["attributes"]
    assert_equal "status", attrs.first["key"]
    assert_equal "success", attrs.first.dig("value", "stringValue")
  end

  test "resource attributes use OTel semantic convention keys" do
    @shipper << "line"

    request_body = nil
    Net::HTTP.any_instance.stubs(:request).with do |req|
      request_body = JSON.parse(req.body)
      true
    end.returns(Net::HTTPOK.new("1.1", "200", "OK"))

    @shipper.flush

    resource_attrs = request_body.dig("resourceLogs", 0, "resource", "attributes")
    keys = resource_attrs.map { |a| a["key"] }
    assert_includes keys, "service.name"
    assert_includes keys, "deploy.performer"
    assert_includes keys, "deploy.version"
    assert_includes keys, "deployment.environment.name"

    service = resource_attrs.find { |a| a["key"] == "service.name" }
    assert_equal "myapp", service.dig("value", "stringValue")

    performer = resource_attrs.find { |a| a["key"] == "deploy.performer" }
    assert_equal "deployer", performer.dig("value", "stringValue")
  end

  test "ignores lines after shutdown" do
    @shipper.shutdown
    @shipper << "too late"

    lines, _events = @shipper.send(:drain_buffer)
    assert_empty lines
  end

  test "HTTP errors are silently swallowed" do
    @shipper << "line"
    Net::HTTP.any_instance.stubs(:request).raises(Errno::ECONNREFUSED)

    assert_nothing_raised { @shipper.flush }
  end
end
