require_relative "integration_test"

class LockTest < IntegrationTest
  test "acquire, release, status" do
    kamal :lock, :acquire, "-m 'Integration Tests'"

    status = kamal :lock, :status, capture: true
    assert_match /Locked by: Deployer at .*\nVersion: #{latest_app_version}\nMessage: Integration Tests/m, status

    error = kamal :deploy, capture: true, raise_on_error: false
    assert_match /Deploy lock found. Run 'kamal lock help' for more information/m, error

    kamal :lock, :release

    status = kamal :lock, :status, capture: true
    assert_match /There is no deploy lock/m, status
  end
end
