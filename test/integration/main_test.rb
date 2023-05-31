require_relative "integration_test"

class MainTest < IntegrationTest
  test "deploy, redeploy, rollback, details and audit" do
    first_version = latest_app_version

    assert_app_is_down

    mrsk :deploy
    assert_app_is_up version: first_version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "post-deploy"

    second_version = update_app_rev

    mrsk :redeploy
    assert_app_is_up version: second_version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "post-deploy"

    mrsk :rollback, first_version
    assert_hooks_ran "pre-connect", "pre-deploy", "post-deploy"
    assert_app_is_up version: first_version

    details = mrsk :details, capture: true
    assert_match /Traefik Host: vm1/, details
    assert_match /Traefik Host: vm2/, details
    assert_match /App Host: vm1/, details
    assert_match /App Host: vm2/, details
    assert_match /traefik:v2.9/, details
    assert_match /registry:4443\/app:#{first_version}/, details

    audit = mrsk :audit, capture: true
    assert_match /Booted app version #{first_version}.*Booted app version #{second_version}.*Booted app version #{first_version}.*/m, audit
  end

  test "envify" do
    mrsk :envify

    assert_equal "SECRET_TOKEN=1234", deployer_exec("cat .env", capture: true)
  end

  test "config" do
    config = YAML.load(mrsk(:config, capture: true))
    version = latest_app_version

    assert_equal [ "web" ], config[:roles]
    assert_equal [ "vm1", "vm2" ], config[:hosts]
    assert_equal "vm1", config[:primary_host]
    assert_equal version, config[:version]
    assert_equal "registry:4443/app", config[:repository]
    assert_equal "registry:4443/app:#{version}", config[:absolute_image]
    assert_equal "app-#{version}", config[:service_with_version]
    assert_equal [], config[:env_args]
    assert_equal [], config[:volume_args]
    assert_equal({ user: "root", auth_methods: [ "publickey" ] }, config[:ssh_options])
    assert_equal({ "multiarch" => false, "args" => { "COMMIT_SHA" => version } }, config[:builder])
    assert_equal [ "--log-opt", "max-size=\"10m\"" ], config[:logging]
    assert_equal({ "path" => "/up", "port" => 3000, "max_attempts" => 7, "cmd" => "wget -qO- http://localhost > /dev/null" }, config[:healthcheck])
  end
end
