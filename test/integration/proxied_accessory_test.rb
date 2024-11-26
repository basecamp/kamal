require_relative "integration_test"

class ProxiedAccessoryTest < IntegrationTest
  test "boot, stop, start, restart, logs, remove" do
    @app = "app_with_proxied_accessory"

    kamal :deploy

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
    def assert_accessory_running(name)
      assert_match /registry:4443\/busybox:1.36.0   "sh -c 'echo \\"Start/, accessory_details(name)
    end

    def assert_accessory_not_running(name)
      assert_no_match /registry:4443\/busybox:1.36.0   "sh -c 'echo \\"Start/, accessory_details(name)
    end

    def accessory_details(name)
      kamal :accessory, :details, name, capture: true
    end

    def assert_netcat_is_up
      response = netcat_response
      debug_response_code(response, "200")
      assert_equal "200", response.code
    end

    def assert_netcat_not_found
      response = netcat_response
      debug_response_code(response, "404")
      assert_equal "404", response.code
    end

    def netcat_response
      uri = URI.parse("http://127.0.0.1:12345/up")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri)
      request["Host"] = "netcat"

      http.request(request)
    end
end
