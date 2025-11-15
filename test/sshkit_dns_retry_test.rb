require "test_helper"

class SshkitDnsRetryTest < ActiveSupport::TestCase
  setup do
    SSHKit::Backend::Netssh.configure { |config| config.dns_retries = 2 }
  end

  test "retries dns errors" do
    attempts = 0

    result = SSHKit::Backend::Netssh.with_dns_retry("example.com") do
      attempts += 1
      raise SocketError, "getaddrinfo: Temporary failure in name resolution" if attempts < 3
      :ok
    end

    assert_equal 3, attempts
    assert_equal :ok, result
  end

  test "does not retry non dns errors" do
    attempts = 0

    assert_raises Errno::ECONNREFUSED do
      SSHKit::Backend::Netssh.with_dns_retry("example.com") do
        attempts += 1
        raise Errno::ECONNREFUSED
      end
    end

    assert_equal 1, attempts
  end
end
