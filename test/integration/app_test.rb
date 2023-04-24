require_relative "integration_test"

class AppTest < IntegrationTest
  test "stop, start, boot, logs, images, containers, exec, remove" do
    mrsk :deploy

    assert_app_is_up

    mrsk :app, :stop

    # traefik is up and returns 404s when it can't match a route
    assert_app_not_found

    mrsk :app, :start

    # mrsk app start does not wait
    wait_for_app_to_be_up

    mrsk :app, :boot

    wait_for_app_to_be_up

    logs = mrsk :app, :logs, capture: true
    assert_match /App Host: vm1/, logs
    assert_match /App Host: vm2/, logs
    assert_match /GET \/ HTTP\/1.1/, logs

    images = mrsk :app, :images, capture: true
    assert_match /App Host: vm1/, images
    assert_match /App Host: vm2/, images
    assert_match /registry:4443\/app\s+#{latest_app_version}/, images
    assert_match /registry:4443\/app\s+latest/, images

    containers = mrsk :app, :containers, capture: true
    assert_match /App Host: vm1/, containers
    assert_match /App Host: vm2/, containers
    assert_match /registry:4443\/app:#{latest_app_version}/, containers
    assert_match /registry:4443\/app:latest/, containers

    exec_output = mrsk :app, :exec, :ps, capture: true
    assert_match /App Host: vm1/, exec_output
    assert_match /App Host: vm2/, exec_output
    assert_match /1 root      0:\d\d ps/, exec_output

    exec_output = mrsk :app, :exec, "--reuse", :ps, capture: true
    assert_match /App Host: vm1/, exec_output
    assert_match /App Host: vm2/, exec_output
    assert_match /1 root      0:\d\d nginx/, exec_output

    mrsk :app, :remove

    # traefik is up and returns 404s when it can't match a route
    assert_app_not_found
  end
end
