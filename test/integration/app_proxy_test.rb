require_relative "integration_test"

class AppProxyTest < IntegrationTest
  setup do
    @app = "app_with_roles"
  end

  test "boot, reboot, stop, start, pause_app, resume_app, restart, logs, remove" do
    kamal :deploy

    kamal :proxy, :boot
    assert_proxy_running

    kamal :proxy, :pause_app
    assert_proxy_app_paused

    kamal :proxy, :resume_app
    assert_proxy_app_running
  end
end
