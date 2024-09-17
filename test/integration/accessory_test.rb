require_relative "integration_test"

class AccessoryTest < IntegrationTest
  test "boot, stop, start, restart, logs, remove" do
    kamal :accessory, :boot, :busybox
    assert_accessory_running :busybox

    kamal :accessory, :stop, :busybox
    assert_accessory_not_running :busybox

    kamal :accessory, :start, :busybox
    assert_accessory_running :busybox

    kamal :accessory, :restart, :busybox
    assert_accessory_running :busybox

    logs = kamal :accessory, :logs, :busybox, capture: true
    assert_match /Starting busybox.../, logs

    kamal :accessory, :remove, :busybox, "-y"
    assert_accessory_not_running :busybox
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
end
