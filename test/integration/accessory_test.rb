require_relative "integration_test"

class AccessoryTest < IntegrationTest
  test "boot, stop, start, restart, logs, remove" do
    mrsk :accessory, :boot, :busybox
    assert_accessory_running :busybox

    mrsk :accessory, :stop, :busybox
    assert_accessory_not_running :busybox

    mrsk :accessory, :start, :busybox
    assert_accessory_running :busybox

    mrsk :accessory, :restart, :busybox
    assert_accessory_running :busybox

    logs = mrsk :accessory, :logs, :busybox, capture: true
    assert_match /Starting busybox.../, logs

    mrsk :accessory, :remove, :busybox, "-y"
    assert_accessory_not_running :busybox
  end

  private
    def assert_accessory_running(name)
      assert_match /registry:4443\/busybox:1.36.0   "sh -c 'echo \\"Start/, accessory_details(name)
    end

    def assert_accessory_not_running(name)
      refute_match /registry:4443\/busybox:1.36.0   "sh -c 'echo \\"Start/, accessory_details(name)
    end

    def accessory_details(name)
      mrsk :accessory, :details, name, capture: true
    end
end
