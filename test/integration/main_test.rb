require_relative "integration_test"

class MainTest < IntegrationTest
  test "envify, deploy, redeploy, rollback, details and audit" do
    kamal :envify
    assert_local_env_file "SECRET_TOKEN=1234"
    assert_remote_env_file "SECRET_TOKEN=1234\nCLEAR_TOKEN=4321"

    first_version = latest_app_version

    assert_app_is_down

    kamal :deploy
    assert_app_is_up version: first_version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "post-deploy"

    second_version = update_app_rev

    kamal :redeploy
    assert_app_is_up version: second_version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "post-deploy"

    kamal :rollback, first_version
    assert_hooks_ran "pre-connect", "pre-deploy", "post-deploy"
    assert_app_is_up version: first_version

    details = kamal :details, capture: true
    assert_match /Traefik Host: vm1/, details
    assert_match /Traefik Host: vm2/, details
    assert_match /App Host: vm1/, details
    assert_match /App Host: vm2/, details
    assert_match /traefik:v2.9/, details
    assert_match /registry:4443\/app:#{first_version}/, details

    audit = kamal :audit, capture: true
    assert_match /Booted app version #{first_version}.*Booted app version #{second_version}.*Booted app version #{first_version}.*/m, audit

    kamal :env, :delete
    assert_no_remote_env_file
  end

  test "config" do
    config = YAML.load(kamal(:config, capture: true))
    version = latest_app_version

    assert_equal [ "web" ], config[:roles]
    assert_equal [ "vm1", "vm2" ], config[:hosts]
    assert_equal "vm1", config[:primary_host]
    assert_equal version, config[:version]
    assert_equal "registry:4443/app", config[:repository]
    assert_equal "registry:4443/app:#{version}", config[:absolute_image]
    assert_equal "app-#{version}", config[:service_with_version]
    assert_equal [], config[:volume_args]
    assert_equal({ user: "root", keepalive: true, keepalive_interval: 30, log_level: :fatal }, config[:ssh_options])
    assert_equal({ "multiarch" => false, "args" => { "COMMIT_SHA" => version } }, config[:builder])
    assert_equal [ "--log-opt", "max-size=\"10m\"" ], config[:logging]
    assert_equal({ "path" => "/up", "port" => 3000, "max_attempts" => 7, "exposed_port" => 3999, "cord"=>"/tmp/kamal-cord", "cmd"=>"wget -qO- http://localhost > /dev/null || exit 1" }, config[:healthcheck])
  end

  private
    def assert_local_env_file(contents)
      assert_equal contents, deployer_exec("cat .env", capture: true)
    end

    def assert_remote_env_file(contents)
      assert_equal contents, docker_compose("exec vm1 cat /root/.kamal/env/roles/app-web.env", capture: true)
    end

    def assert_no_remote_env_file
      assert_equal "nofile", docker_compose("exec vm1 stat /root/.kamal/env/roles/app-web.env 2> /dev/null || echo nofile", capture: true)
    end
end
