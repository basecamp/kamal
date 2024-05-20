require_relative "integration_test"

class BrokenDeployTest < IntegrationTest
  test "deploying a bad image" do
    @app = "app_with_roles"

    kamal :envify

    first_version = latest_app_version

    kamal :deploy

    assert_app_is_up version: first_version
    assert_container_running host: :vm3, name: "app-workers-#{first_version}"

    second_version = break_app

    output = kamal :deploy, raise_on_error: false, capture: true

    assert_failed_deploy output
    assert_app_is_up version: first_version
    assert_container_running host: :vm3, name: "app-workers-#{first_version}"
    assert_container_not_running host: :vm3, name: "app-workers-#{second_version}"
  end

  private
    def assert_failed_deploy(output)
      assert_match "Waiting for a healthy web container (vm3)...", output
      assert_match /First #{KAMAL.primary_role} container is unhealthy, stopping \(vm[12]\)/, output
      assert_match "First #{KAMAL.primary_role} container unhealthy, stopping other roles (vm3)...", output
      assert_match "nginx: [emerg] unexpected end of file, expecting \";\" or \"}\" in /etc/nginx/conf.d/default.conf:2", output
      assert_match 'ERROR {"Status":"unhealthy","FailingStreak":0,"Log":[]}', output
    end
end
