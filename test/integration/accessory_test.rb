require_relative "integration_test"

class AccessoryTest < IntegrationTest
  # The busybox accessory is on the web role, so it runs on both hosts.
  ACCESSORY_HOSTS = [ "vm1", "vm2" ]

  test "boot, stop, start, restart, logs, remove" do
    kamal :accessory, :boot, :busybox
    assert_accessory_running :busybox
    assert_accessory_volume_mount_options :busybox
    assert_accessory_file_mode_and_owner :busybox
    assert_accessory_directory_mode_and_owner :busybox

    kamal :accessory, :stop, :busybox
    assert_accessory_not_running :busybox

    kamal :accessory, :start, :busybox
    assert_accessory_running :busybox

    kamal :accessory, :restart, :busybox
    assert_accessory_running :busybox

    logs = kamal :accessory, :logs, :busybox, capture: true
    assert_match /Starting busybox.../, logs

    boot = kamal :accessory, :boot, :busybox, capture: true
    assert_match /Skipping booting `busybox` on vm1, vm2, a container already exists/, boot

    # Rebooting onto the same image must keep it — docker refuses to remove an
    # image a container still references.
    reboot = kamal :accessory, :reboot, :busybox, capture: true
    assert_match /Kept busybox image sha256:\h+ on vm\d, docker declined to remove it/, reboot
    assert_accessory_running :busybox
    ACCESSORY_HOSTS.each { |host| assert_includes image_tags(host), "busybox:1.36.0" }

    # Point the accessory at a different image, so the reboot supersedes the one
    # it is running and the old id becomes unreferenced on every host.
    superseded = accessory_image_ids
    deployer_exec "sed -i 's|image: busybox:1.36.0|image: busybox:1.37.0|' config/deploy.yml"

    kamal :accessory, :reboot, :busybox
    assert_accessory_running :busybox, version: "1.37.0"
    superseded.each do |host, image_id|
      assert_not_equal image_id, accessory_image_id(host)
      assert_not_includes image_ids(host), image_id
    end

    kamal :accessory, :remove, :busybox, "-y"
    assert_accessory_not_running :busybox
  end

  test "proxied: boot, stop, start, restart, logs, remove" do
    @app = "app_with_proxied_accessory"

    kamal :proxy, :boot

    kamal :accessory, :boot, :netcat
    assert_accessory_running :netcat
    assert_netcat_is_up

    kamal :accessory, :stop, :netcat
    assert_accessory_not_running :netcat
    assert_netcat_not_found

    kamal :accessory, :start, :netcat
    assert_accessory_running :netcat
    assert_netcat_is_up

    kamal :accessory, :restart, :netcat
    assert_accessory_running :netcat
    assert_netcat_is_up

    kamal :accessory, :remove, :netcat, "-y"
    assert_accessory_not_running :netcat
    assert_netcat_not_found
  end

  private
    def assert_accessory_running(name, version: "1.36.0")
      assert_match /busybox:#{version}   "sh -c 'echo \\"Start/, accessory_details(name)
    end

    # Version-agnostic, so the check still covers removal after the accessory
    # has been repointed at another image.
    def assert_accessory_not_running(name)
      assert_no_match /busybox:\S+   "sh -c 'echo \\"Start/, accessory_details(name)
    end

    def assert_accessory_volume_mount_options(name)
      mounts = docker_compose("exec vm1 docker inspect custom-busybox --format '{{json .Mounts}}'", capture: true)
      assert_match %r{/data.*"RW":false}, mounts, "Expected read-only mount option (:ro) to be applied"
    end

    def assert_accessory_file_mode_and_owner(name)
      file_stat = docker_compose("exec vm1 stat -c '%a %u:%g' /root/custom-busybox/etc/busybox.conf", capture: true)
      assert_match /640 1000:1000/, file_stat, "Expected file to have 640 mode and 1000:1000 owner"
    end

    def assert_accessory_directory_mode_and_owner(name)
      dir_stat = docker_compose("exec vm1 stat -c '%a %u:%g' /root/custom-busybox/data", capture: true)
      assert_match /750 1000:1000/, dir_stat, "Expected directory to have 750 mode and 1000:1000 owner"
    end

    def accessory_image_ids
      ACCESSORY_HOSTS.to_h { |host| [ host, accessory_image_id(host) ] }
    end

    def accessory_image_id(host)
      docker_compose("exec #{host} docker inspect custom-busybox --format '{{.Image}}'", capture: true).strip
    end

    def image_ids(host)
      docker_compose("exec #{host} docker image ls -aq --no-trunc", capture: true).lines.map(&:strip)
    end

    def image_tags(host)
      docker_compose("exec #{host} docker image ls busybox --format '{{.Repository}}:{{.Tag}}'", capture: true)
    end

    def accessory_details(name)
      kamal :accessory, :details, name, capture: true
    end

    def assert_netcat_is_up
      assert_equal "200", wait_for_netcat_response("200")
    end

    def assert_netcat_not_found
      assert_equal "404", wait_for_netcat_response("404")
    end

    def wait_for_netcat_response(expected, timeout: 20)
      timeout_at = Time.now + timeout
      response = netcat_response
      while response.code != expected && timeout_at > Time.now
        sleep 0.1
        response = netcat_response
      end
      debug_response_code(response, expected)
      response.code
    end

    def netcat_response
      uri = URI.parse("http://127.0.0.1:#{@http_port}/up")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri)
      request["Host"] = "netcat"

      http.request(request)
    end
end
