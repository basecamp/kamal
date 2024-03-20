require_relative "integration_test"

class IntegrationProxyTest < IntegrationTest
  test "boot, reboot, stop, start, restart, logs, remove" do
    kamal :server, :bootstrap
    kamal :envify

    kamal :proxy, :boot
    assert_proxy_running

    output = kamal :proxy, :reboot, capture: true
    assert_proxy_running
    assert_hooks_ran "pre-proxy-reboot", "post-proxy-reboot"
    assert_match /Rebooting proxy on vm1,vm2.../, output
    assert_match /Rebooted proxy on vm1,vm2/, output

    output = kamal :proxy, :reboot, :"--rolling", capture: true
    assert_proxy_running
    assert_hooks_ran "pre-proxy-reboot", "post-proxy-reboot"
    assert_match /Rebooting proxy on vm1.../, output
    assert_match /Rebooted proxy on vm1/, output
    assert_match /Rebooting proxy on vm2.../, output
    assert_match /Rebooted proxy on vm2/, output

    kamal :proxy, :boot
    assert_proxy_running

    # Check booting when booted doesn't raise an error
    kamal :proxy, :stop
    assert_proxy_not_running

    # Check booting when stopped works
    kamal :proxy, :boot
    assert_proxy_running

    kamal :proxy, :stop
    assert_proxy_not_running

    kamal :proxy, :start
    assert_proxy_running

    kamal :proxy, :restart
    assert_proxy_running

    logs = kamal :proxy, :logs, capture: true
    assert_match %r["level":"INFO","msg":"Server started","http":80,"https":443], logs

    kamal :proxy, :remove
    assert_proxy_not_running

    kamal :env, :delete
  end

  private
    def assert_proxy_running
      assert_match %r[registry:4443/dmcbreen/mproxy:latest   "mproxy run"], proxy_details
    end

    def assert_proxy_not_running
      refute_match %r[registry:4443/dmcbreen/mproxy:latest   "mproxy run"], proxy_details
    end

    def proxy_details
      kamal :proxy, :details, capture: true
    end
end
