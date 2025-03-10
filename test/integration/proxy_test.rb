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

    kamal :proxy, :boot_config, :set, "--docker-options='sysctl net.ipv4.ip_local_port_range=\"10000 60999\"'"
        assert_docker_options_in_file

    kamal :proxy, :reboot, "-y"
    assert_docker_options_in_container
    
    kamal :proxy, :boot_config, :reset

    kamal :proxy, :remove
    assert_proxy_not_running
  end

  private
    def assert_docker_options_in_file
      boot_config = kamal :proxy, :boot_config, :get, capture: true
      assert_match "Host vm1: --publish 80:80 --publish 443:443 --log-opt max-size=10m --sysctl net.ipv4.ip_local_port_range=\"10000 60999\"", boot_config
    end

    def assert_docker_options_in_container
      assert_equal \
        "{\"net.ipv4.ip_local_port_range\":\"10000 60999\"}", 
        docker_compose("exec vm1 docker inspect --format '{{ json .HostConfig.Sysctls }}' kamal-proxy", capture: true).strip
    end
end
