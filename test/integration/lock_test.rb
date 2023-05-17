require_relative "integration_test"

class LockTest < IntegrationTest
  test "acquire, release, status" do
    mrsk :lock, :acquire, "-m 'Integration Tests'"

    status = mrsk :lock, :status, capture: true
    assert_match /Locked by: Deployer at .*\nVersion: #{latest_app_version}\nMessage: Integration Tests/m, status

    error = mrsk :deploy, capture: true, raise_on_error: false
    assert_match /Deploy lock found/m, error

    mrsk :lock, :release

    status = mrsk :lock, :status, capture: true
    assert_match /There is no deploy lock/m, status
  end
end
