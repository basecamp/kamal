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
    assert_hooks_ran "pre-traefik-reboot", "post-traefik-reboot"
    assert_match /Rebooting Traefik on vm1,vm2.../, output
    assert_match /Rebooted Traefik on vm1,vm2/, output

    output = kamal :proxy, :reboot, "--rolling", "-y", "--verbose", capture: true
    assert_proxy_running
    assert_hooks_ran "pre-traefik-reboot", "post-traefik-reboot"
    assert_match /Rebooting Traefik on vm1.../, output
    assert_match /Rebooted Traefik on vm1/, output
    assert_match /Rebooting Traefik on vm2.../, output
    assert_match /Rebooted Traefik on vm2/, output

    kamal :proxy, :boot
    assert_proxy_running
    assert_traefik_running

    # Check booting when booted doesn't raise an error
    kamal :proxy, :stop
    assert_proxy_not_running
    assert_traefik_not_running

    # Check booting when stopped works
    kamal :proxy, :boot
    assert_proxy_running
    assert_traefik_running

    kamal :proxy, :stop
    assert_proxy_not_running
    assert_traefik_not_running

    kamal :proxy, :start
    assert_proxy_running
    assert_traefik_running

    kamal :proxy, :restart
    assert_proxy_running
    assert_traefik_running

    logs = kamal :proxy, :logs, capture: true
    assert_match /Traefik version [\d.]+ built on/, logs

    kamal :proxy, :remove
    assert_proxy_not_running
    assert_traefik_not_running

    kamal :env, :delete
  end

  private
    def assert_proxy_running
      assert_match /basecamp\/kamal-proxy:latest   \"kamal-proxy run\"/, proxy_details
    end

    def assert_proxy_not_running
      assert_no_match /basecamp\/kamal-proxy:latest   \"kamal-proxy run\"/, proxy_details
    end

    def assert_traefik_running
      assert_match /traefik:v2.10   "\/entrypoint.sh/, proxy_details
    end

    def assert_traefik_not_running
      assert_no_match /traefik:v2.10   "\/entrypoint.sh/, proxy_details
    end

    def proxy_details
      kamal :proxy, :details, capture: true
    end
end
