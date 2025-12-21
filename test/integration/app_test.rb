require_relative "integration_test"

class AppTest < IntegrationTest
  test "stop, start, boot, logs, images, containers, exec, remove" do
    kamal :deploy

    assert_app_is_up

    kamal :app, :stop

    assert_app_not_found

    kamal :app, :start

    # kamal app start does not wait
    wait_for_app_to_be_up

    output = kamal :app, :boot, "--verbose", capture: true
    assert_match "Booting app on vm1,vm2...", output
    assert_match "Booted app on vm1,vm2...", output

    wait_for_app_to_be_up

    logs = kamal :app, :logs, capture: true
    assert_match "App Host: vm1", logs
    assert_match "App Host: vm2", logs
    assert_match "GET /version HTTP/1.1", logs

    images = kamal :app, :images, capture: true
    assert_match "App Host: vm1", images
    assert_match "App Host: vm2", images
    assert_match /localhost:5000\/app\s+#{latest_app_version}/, images
    assert_match /localhost:5000\/app\s+latest/, images

    containers = kamal :app, :containers, capture: true
    assert_match "App Host: vm1", containers
    assert_match "App Host: vm2", containers
    assert_match "localhost:5000/app:#{latest_app_version}", containers
    assert_match "localhost:5000/app:latest", containers

    exec_output = kamal :app, :exec, :ps, capture: true
    assert_match "App Host: vm1", exec_output
    assert_match "App Host: vm2", exec_output
    assert_match /1 root      0:\d\d ps/, exec_output

    exec_output = kamal :app, :exec, "--reuse", :ps, capture: true
    assert_match "App Host: vm2", exec_output
    assert_match "App Host: vm1", exec_output
    assert_match /1 root      0:\d\d nginx/, exec_output

    kamal :app, :maintenance
    assert_app_in_maintenance

    kamal :app, :live
    assert_app_is_up

    kamal :app, :remove

    assert_app_not_found
    assert_app_directory_removed
  end

  test "parallel roles" do
    @app = "app_with_parallel_roles"

    version = latest_app_version

    kamal :deploy

    assert_app_is_up version: version
    assert_container_running host: :vm1, name: "app_with_parallel_roles-web-#{version}"
    assert_container_running host: :vm1, name: "app_with_parallel_roles-workers-#{version}"
    assert_container_running host: :vm2, name: "app_with_parallel_roles-web-#{version}"

    kamal :app, :stop

    assert_app_not_found

    kamal :app, :start

    wait_for_app_to_be_up

    logs = kamal :app, :logs, capture: true
    assert_match /role=web.* on vm1/, logs
    assert_match /role=web.* on vm2/, logs
    assert_match /role=workers.* on vm1/, logs

    # Images runs once per host (not per role)
    images = kamal :app, :images, capture: true
    assert_match "App Host: vm1", images
    assert_match "App Host: vm2", images
    assert_equal 2, images.scan(/App Host:/).count

    # Containers runs once per host (not per role)
    containers = kamal :app, :containers, capture: true
    assert_match "App Host: vm1", containers
    assert_match "App Host: vm2", containers
    assert_match "app_with_parallel_roles-web", containers
    assert_match "app_with_parallel_roles-workers", containers
    assert_equal 2, containers.scan(/App Host:/).count

    # Exec runs per role per host: web on vm1, web on vm2, workers on vm1
    exec_output = kamal :app, :exec, :hostname, capture: true
    assert_match /app_with_parallel_roles-web-exec-.* on vm1/, exec_output
    assert_match /app_with_parallel_roles-web-exec-.* on vm2/, exec_output
    assert_match /app_with_parallel_roles-workers-exec-.* on vm1/, exec_output
    assert_equal 3, exec_output.scan(/App Host:/).count

    kamal :app, :maintenance
    assert_app_in_maintenance

    kamal :app, :live
    assert_app_is_up
  end

  test "custom error pages" do
    @app = "app_with_roles"

    kamal :deploy
    assert_app_is_up

    kamal :app, :maintenance
    assert_app_in_maintenance message: "Custom Maintenance Page"

    kamal :app, :live
    kamal :app, :maintenance, "--message", "\"Testing Maintence Mode\""
    assert_app_in_maintenance message: "Custom Maintenance Page: Testing Maintence Mode"

    second_version = update_app_rev

    kamal :redeploy

    kamal :app, :maintenance
    assert_app_in_maintenance message: "Custom Maintenance Page"
  end
end
