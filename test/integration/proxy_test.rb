require_relative "integration_test"

class ProxyTest < IntegrationTest
  setup do
    @app = "app_with_roles"
  end

  test "boot, reboot, stop, start, restart, logs, remove" do
    kamal :proxy, :boot
    assert_proxy_running

    output = kamal :proxy, :reboot, "-y", "--verbose", capture: true
    assert_proxy_running
    assert_hooks_ran "pre-proxy-reboot", "post-proxy-reboot"
    assert_match /Rebooting kamal-proxy on vm1,vm2.../, output
    assert_match /Rebooted kamal-proxy on vm1,vm2/, output

    output = kamal :proxy, :reboot, "--rolling", "-y", "--verbose", capture: true
    assert_proxy_running
    assert_hooks_ran "pre-proxy-reboot", "post-proxy-reboot"
    assert_match /Rebooting kamal-proxy on vm1.../, output
    assert_match /Rebooted kamal-proxy on vm1/, output
    assert_match /Rebooting kamal-proxy on vm2.../, output
    assert_match /Rebooted kamal-proxy on vm2/, output

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
    assert_match /No previous state to restore/, logs

    kamal :proxy, :remove
    assert_proxy_not_running
  end
end
