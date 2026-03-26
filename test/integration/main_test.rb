require_relative "integration_test"

class MainTest < IntegrationTest
  test "deploy, redeploy, rollback, details and audit" do
    first_version = latest_app_version

    assert_app_is_down

    deploy_output = kamal :deploy, capture: true
    assert_app_is_up version: first_version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "pre-app-boot", "post-app-boot", "post-deploy"
    assert_hook_output deploy_output

    assert_envs version: first_version

    output = kamal :app, :exec, "--verbose", "ls", "-r", "web", capture: true
    assert_hook_env_variables output, version: first_version

    second_version = update_app_rev

    kamal :redeploy
    assert_app_is_up version: second_version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "pre-app-boot", "post-app-boot", "post-deploy"

    assert_accumulated_assets first_version, second_version
    assert_asset_volume_read_only second_version

    kamal :rollback, first_version
    assert_hooks_ran "pre-connect", "pre-deploy", "pre-app-boot", "post-app-boot", "post-deploy"
    assert_app_is_up version: first_version

    details = kamal :details, capture: true
    assert_match /Proxy Host: vm1/, details
    assert_match /Proxy Host: vm2/, details
    assert_match /App Host: vm1/, details
    assert_match /App Host: vm2/, details
    assert_match /basecamp\/kamal-proxy:#{Kamal::Configuration::Proxy::Run::MINIMUM_VERSION}/, details
    assert_match /localhost:5000\/app:#{first_version}/, details

    audit = kamal :audit, capture: true
    assert_match /Booted app version #{first_version}.*Booted app version #{second_version}.*Booted app version #{first_version}.*/m, audit
  end

  test "app with roles" do
    @app = "app_with_roles"

    version = latest_app_version

    assert_app_is_down

    kamal :deploy

    assert_app_is_up version: version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "post-deploy"
    assert_container_running host: :vm3, name: "app_with_roles-workers-#{version}"

    second_version = update_app_rev

    kamal :redeploy
    assert_app_is_up version: second_version
    assert_container_running host: :vm3, name: "app_with_roles-workers-#{second_version}"
  end

  test "config" do
    config = YAML.load(kamal(:config, capture: true))
    version = latest_app_version

    assert_equal [ "web" ], config[:roles]
    assert_equal [ "vm1", "vm2", "vm3" ], config[:hosts]
    assert_equal "vm1", config[:primary_host]
    assert_equal version, config[:version]
    assert_equal "localhost:5000/app", config[:repository]
    assert_equal "localhost:5000/app:#{version}", config[:absolute_image]
    assert_equal "app-#{version}", config[:service_with_version]
    assert_equal [], config[:volume_args]
    assert_equal({ user: "root", port: 22, keepalive: true, keepalive_interval: 30, log_level: :fatal }, config[:ssh_options])
    assert_equal({ "driver" => "docker", "arch" => "#{Kamal::Utils.docker_arch}", "args" => { "COMMIT_SHA" => version } }, config[:builder])
    assert_equal [ "--log-opt", "max-size=\"10m\"" ], config[:logging]
  end

  test "aliases" do
    @app = "app_with_roles"

    kamal :deploy

    output = kamal :whome, capture: true
    assert_equal Kamal::VERSION, output

    output = kamal :worker_hostname, capture: true
    assert_match /App Host: vm3\nvm3-[0-9a-f]{12}$/, output

    output = kamal :worker_hostname_quiet, capture: true
    assert_match /vm3-[0-9a-f]{12}$/, output

    output = kamal :uname, "-o", capture: true
    assert_match "App Host: vm1\nGNU/Linux", output

    output = kamal :uname_quiet, "-o", capture: true
    assert_match "GNU/Linux", output
  end

  test "deploy with destinations" do
    @app = "app_with_destinations"

    kamal :staging_deploy
    assert_app_is_up

    config = YAML.load(kamal(:staging_config, capture: true))
    assert_equal [ "vm1" ], config[:hosts]

    config = YAML.load(kamal(:production_config, capture: true))
    assert_equal [ "vm2", "vm3" ], config[:hosts]
  end

  test "setup and remove" do
    kamal :proxy, :boot_config, "set",
      "--publish=false",
      "--docker-options=label=traefik.http.services.kamal_proxy.loadbalancer.server.scheme=http",
      "label=traefik.http.routers.kamal_proxy.rule=PathPrefix\\\(\\\`/\\\`\\\)",
      "label=traefik.http.routers.kamal_proxy.priority=2"

    # Check remove completes when nothing has been setup yet
    kamal :remove, "-y"
    assert_no_images_or_containers

    kamal :setup
    assert_images_and_containers

    kamal :remove, "-y"
    assert_no_images_or_containers
    assert_app_directory_removed
  end

  test "two apps" do
    @app = "app"
    kamal :deploy
    app1_version = latest_app_version

    @app = "app_with_roles"
    kamal :deploy
    app2_version = latest_app_version

    assert_app_is_up version: app1_version, app: "app"
    assert_app_is_up version: app2_version, app: "app_with_roles"

    @app = "app"
    kamal :remove, "-y"
    assert_app_directory_removed
    assert_proxy_running

    @app = "app_with_roles"
    kamal :remove, "-y"
    assert_app_directory_removed
    assert_proxy_not_running
  end

  test "deploy with traefik" do
    @app = "app_with_traefik"

    first_version = latest_app_version

    kamal :setup
    assert_app_is_up version: first_version
  end

  test "deploy with a custom certificate" do
    @app = "app_with_custom_certificate"

    first_version = latest_app_version

    kamal :setup

    assert_app_is_up version: first_version, cert: "test/integration/docker/deployer/app_with_custom_certificate/certs/cert.pem"
  end

  private
    def assert_envs(version:)
      assert_env :KAMAL_HOST, "vm1", version: version, vm: :vm1
      assert_env :CLEAR_TOKEN, "4321", version: version, vm: :vm1
      assert_env :HOST_TOKEN, "abcd", version: version, vm: :vm1
      assert_env :SECRET_TOKEN, "1234 with \"中文\"", version: version, vm: :vm1
      assert_no_env :CLEAR_TAG, version: version, vm: :vm1
      assert_no_env :SECRET_TAG, version: version, vm: :vm1
      assert_env :CLEAR_TAG, "tagged", version: version, vm: :vm2
      assert_env :SECRET_TAG, "TAGME", version: version, vm: :vm2
      assert_env :INTERPOLATED_SECRET1, "1TERCES_DETALOPRETNI", version: version, vm: :vm2
      assert_env :INTERPOLATED_SECRET2, "2TERCES_DETALOPRETNI", version: version, vm: :vm2
      assert_env :INTERPOLATED_SECRET3, "文中_DETALOPRETNI", version: version, vm: :vm2
      assert_env :INTERPOLATED_SECRET4, ")(_DETALOPRETNI", version: version, vm: :vm2
    end

    def assert_env(key, value, vm:, version:)
      assert_equal "#{key}=#{value}", docker_compose("exec #{vm} docker exec #{@app}-web-#{version} env | grep #{key}", capture: true)
    end

    def assert_no_env(key, vm:, version:)
      assert_raises(RuntimeError, /exit 1/) do
        docker_compose("exec #{vm} docker exec #{@app}-web-#{version} env | grep #{key}", capture: true)
      end
    end

    def assert_accumulated_assets(*versions)
      versions.each do |version|
        assert_equal "200", Net::HTTP.get_response(URI.parse("http://#{app_host}:12345/versions/#{version}")).code
      end

      assert_equal "200", Net::HTTP.get_response(URI.parse("http://#{app_host}:12345/versions/.hidden")).code
    end

    def assert_asset_volume_read_only(version)
      mounts = docker_compose("exec vm1 docker inspect app-web-#{version} --format '{{json .Mounts}}'", capture: true)
      assert_match %r{/usr/share/nginx/html/versions.*"RW":false}, mounts, "Expected asset volume to be mounted read-only (:ro)"
    end

    def image_ids(vm:)
      docker_compose("exec #{vm} docker image ls -q", capture: true).strip.split("\n")
    end

    def container_ids(vm:)
      docker_compose("exec #{vm} docker ps -a -q", capture: true).strip.split("\n")
    end

    def assert_no_images_or_containers
      [ :vm1, :vm2, :vm3 ].each do |vm|
        assert image_ids(vm: vm).empty?
        assert container_ids(vm: vm).empty?
      end
    end

    def assert_images_and_containers
      [ :vm1, :vm2, :vm3 ].each do |vm|
        assert image_ids(vm: vm).any?
        assert container_ids(vm: vm).any?
      end
    end

    def assert_hook_env_variables(output, version:)
      assert_match "KAMAL_VERSION=#{version}", output
      assert_match "KAMAL_SERVICE=app", output
      assert_match "KAMAL_SERVICE_VERSION=app@#{version[0..6]}", output
      assert_match "KAMAL_COMMAND=app", output
      assert_match "KAMAL_PERFORMER=deployer@example.com", output
      assert_match /KAMAL_RECORDED_AT=\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ/, output
      assert_match "KAMAL_HOSTS=vm1,vm2", output
      assert_match "KAMAL_ROLES=web", output
    end

    def assert_hook_output(output)
      # pre-deploy hook (hooks_output: :verbose) shows everything
      assert_match(/Running.*pre-deploy/, output)
      assert_match(/Deployed!/, output)
      # pre-build hook (hooks_output: :quiet) hides everything
      assert_no_match(/Running.*pre-build/, output)
      assert_no_match(/About to build and push/, output)
      # post-deploy hook (no hooks_output setting) shows Running but hides output
      assert_match(/Running.*post-deploy/, output)
      assert_no_match(/Finished deploy!/, output)
    end
end
