require "test_helper"

class OutputOtelLoggerTest < ActiveSupport::TestCase
  setup do
    @tags = Kamal::Tags.new(
      performer: "deployer",
      service: "myapp",
      version: "abc123",
      destination: "production"
    )
    Kamal::OtelShipper.any_instance.stubs(:start_flush_thread)
    Kamal::OtelShipper.any_instance.stubs(:flush)
    @logger = Kamal::Output::OtelLogger.new(endpoint: "http://localhost:4318", tags: @tags, service: "myapp")
  end

  teardown do
    @logger.close
  end

  test "start event includes subcommand in command" do
    Kamal::OtelShipper.any_instance.expects(:event).with("kamal.start", "kamal.command": "app boot")
    @logger.start("modify.kamal", "id", command: "app", subcommand: "boot", hosts: [ "1.1.1.1" ])
  end

  test "start event uses just command when no subcommand" do
    Kamal::OtelShipper.any_instance.expects(:event).with("kamal.start",
      "kamal.command": "deploy",
      "deployment.id": anything, "deployment.name": "deploy myapp")
    @logger.start("modify.kamal", "id", command: "deploy", subcommand: nil, hosts: [ "1.1.1.1" ])
  end

  test "deploy complete event includes deployment status" do
    @logger.start("modify.kamal", "id", command: "deploy", hosts: [ "1.1.1.1" ])
    Kamal::OtelShipper.any_instance.expects(:event).with("kamal.complete",
      "kamal.command": "deploy", "kamal.runtime": anything,
      "deployment.id": anything, "deployment.name": "deploy myapp", "deployment.status": "succeeded")
    @logger.finish("modify.kamal", "id", command: "deploy")
  end

  test "deploy failed event includes deployment status" do
    @logger.start("modify.kamal", "id", command: "deploy", hosts: [ "1.1.1.1" ])
    Kamal::OtelShipper.any_instance.expects(:event).with("kamal.failed",
      severity: :error, "kamal.command": "deploy", "kamal.runtime": anything,
      "exception.type": "RuntimeError", "exception.message": "boom",
      "deployment.id": anything, "deployment.name": "deploy myapp", "deployment.status": "failed")
    @logger.finish("modify.kamal", "id", command: "deploy", exception: [ "RuntimeError", "boom" ])
  end

  test "non-deploy commands omit deployment attributes" do
    Kamal::OtelShipper.any_instance.expects(:event).with("kamal.start", "kamal.command": "app boot")
    @logger.start("modify.kamal", "id", command: "app", subcommand: "boot", hosts: [ "1.1.1.1" ])
  end

  test "complete event includes subcommand" do
    @logger.start("modify.kamal", "id", command: "app", subcommand: "boot", hosts: [ "1.1.1.1" ])
    Kamal::OtelShipper.any_instance.expects(:event).with("kamal.complete", "kamal.command": "app boot", "kamal.runtime": anything)
    @logger.finish("modify.kamal", "id", command: "app", subcommand: "boot")
  end

  test "failed event includes subcommand with error severity and exception attributes" do
    @logger.start("modify.kamal", "id", command: "app", subcommand: "boot", hosts: [ "1.1.1.1" ])
    Kamal::OtelShipper.any_instance.expects(:event).with("kamal.failed",
      severity: :error, "kamal.command": "app boot", "kamal.runtime": anything,
      "exception.type": "RuntimeError", "exception.message": "boom")
    @logger.finish("modify.kamal", "id", command: "app", subcommand: "boot", exception: [ "RuntimeError", "boom" ])
  end

  test "finish prints endpoint" do
    @logger.start("modify.kamal", "id", command: "deploy", hosts: [ "1.1.1.1" ])

    output = capture_io { @logger.finish("modify.kamal", "id", command: "deploy") }.first
    assert_match /Logs sent to http:\/\/localhost:4318/, output
  end

  test "stream output includes host, iostream and severity from thread context" do
    Thread.current[:kamal_host] = "1.1.1.1"
    Thread.current[:kamal_iostream] = "stdout"
    Thread.current[:kamal_severity] = Logger::DEBUG

    Kamal::OtelShipper.any_instance.expects(:append).with("output line\n", host: "1.1.1.1", iostream: "stdout", severity: Logger::DEBUG)
    @logger << "output line\n"
  ensure
    Thread.current[:kamal_host] = nil
    Thread.current[:kamal_iostream] = nil
    Thread.current[:kamal_severity] = nil
  end

  test "stream output without thread context omits host, iostream and severity" do
    Kamal::OtelShipper.any_instance.expects(:append).with("output line\n", host: nil, iostream: nil, severity: nil)
    @logger << "output line\n"
  end
end
