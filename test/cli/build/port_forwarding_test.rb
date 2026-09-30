require "test_helper"

class Kamal::Cli::Build::PortForwardingTest < ActiveSupport::TestCase
  test "connects to the host without the user prefix" do
    ssh = ssh_session_with_successful_forward

    Net::SSH.expects(:start).with("1.2.3.4", "deploy", keepalive: true).yields(ssh)

    assert_forwards [ "deploy@1.2.3.4" ], user: "deploy", keepalive: true
  end

  test "logs and continues when the remote forward is rejected" do
    ssh = ssh_session_with_rejected_forward

    Net::SSH.expects(:start).with("1.2.3.4", nil).yields(ssh)

    assert_forwards [ "1.2.3.4" ] do |errors|
      assert_match "Port forward rejected on 1.2.3.4 (tunnel may already exist)", errors.first
    end
  end

  test "logs and continues when the connection fails" do
    Net::SSH.expects(:start).with("1.2.3.4", "deploy").raises(Errno::ECONNREFUSED, "Connection refused")

    assert_forwards [ "deploy@1.2.3.4" ], user: "deploy" do |errors|
      assert_match /Error setting up port forwarding to deploy@1.2.3.4: Errno::ECONNREFUSED/, errors.first
    end
  end

  private
    def assert_forwards(hosts, **ssh_options)
      recorder = ErrorRecorder.new
      original_output = SSHKit.config.output
      SSHKit.config.output = recorder
      forwarded = false

      Kamal::Cli::Build::PortForwarding.new(hosts, 5000, **ssh_options).forward { forwarded = true }

      assert forwarded, "expected forwarding to complete"
      yield recorder.messages if block_given?
    ensure
      SSHKit.config.output = original_output
    end

    class ErrorRecorder
      attr_reader :messages

      def initialize
        @messages = []
      end

      def error(message)
        @messages << message
      end
    end

    def ssh_session_with_successful_forward
      ssh_session { |forward| forward.stubs(:remote).yields(5000, "127.0.0.1") }
    end

    def ssh_session_with_rejected_forward
      ssh_session { |forward| forward.stubs(:remote).yields(:error, nil) }
    end

    def ssh_session
      forward = mock("forward")
      yield forward

      mock("ssh").tap do |ssh|
        ssh.stubs(:forward).returns(forward)
        ssh.stubs(:loop)
      end
    end
end
