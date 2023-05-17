require_relative "integration_test"

class TraefikTest < IntegrationTest
  test "boot, stop, start, restart, logs, remove" do
    mrsk :traefik, :boot
    assert_traefik_running

    mrsk :traefik, :stop
    assert_traefik_not_running

    mrsk :traefik, :start
    assert_traefik_running

    mrsk :traefik, :restart
    assert_traefik_running

    logs = mrsk :traefik, :logs, capture: true
    assert_match /Traefik version [\d.]+ built on/, logs

    mrsk :traefik, :remove
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
      mrsk :traefik, :details, capture: true
    end
end
