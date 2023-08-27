require_relative "integration_test"

class TraefikTest < IntegrationTest
  test "boot, reboot, stop, start, restart, logs, remove" do
    kamal :traefik, :boot
    assert_traefik_running

    kamal :traefik, :reboot
    assert_traefik_running

    kamal :traefik, :boot
    assert_traefik_running

    # Check booting when booted doesn't raise an error
    kamal :traefik, :stop
    assert_traefik_not_running

    # Check booting when stopped works
    kamal :traefik, :boot
    assert_traefik_running

    kamal :traefik, :stop
    assert_traefik_not_running

    kamal :traefik, :start
    assert_traefik_running

    kamal :traefik, :restart
    assert_traefik_running

    logs = kamal :traefik, :logs, capture: true
    assert_match /Traefik version [\d.]+ built on/, logs

    kamal :traefik, :remove
    assert_traefik_not_running
  end

  private
    def assert_traefik_running
      assert_match /traefik:v2.9   "\/entrypoint.sh/, traefik_details
    end

    def assert_traefik_not_running
      refute_match /traefik:v2.9   "\/entrypoint.sh/, traefik_details
    end

    def traefik_details
      kamal :traefik, :details, capture: true
    end
end
