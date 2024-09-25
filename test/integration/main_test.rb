require_relative "integration_test"

class MainTest < IntegrationTest
  test "deploy, redeploy, rollback, details and audit" do
    first_version = latest_app_version

    assert_app_is_down

    kamal :deploy
    assert_app_is_up version: first_version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "post-deploy"
    assert_envs version: first_version

    second_version = update_app_rev

    kamal :redeploy
    assert_app_is_up version: second_version
    assert_hooks_ran "pre-connect", "pre-build", "pre-deploy", "post-deploy"

    assert_accumulated_assets first_version, second_version

    kamal :rollback, first_version
    assert_hooks_ran "pre-connect", "pre-deploy", "post-deploy"
    assert_app_is_up version: first_version

    details = kamal :details, capture: true
    assert_match /Proxy Host: vm1/, details
    assert_match /Proxy Host: vm2/, details
    assert_match /App Host: vm1/, details
    assert_match /App Host: vm2/, details
    assert_match /basecamp\/kamal-proxy:#{Kamal::Configuration::PROXY_MINIMUM_VERSION}/, details
    assert_match /registry:4443\/app:#{first_version}/, details

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
    assert_equal [ "vm1", "vm2" ], config[:hosts]
    assert_equal "vm1", config[:primary_host]
    assert_equal version, config[:version]
    assert_equal "registry:4443/app", config[:repository]
    assert_equal "registry:4443/app:#{version}", config[:absolute_image]
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

    output = kamal :uname, "-o", capture: true
    assert_match "App Host: vm1\nGNU/Linux", output
  end

  test "setup and remove" do
    @app = "app_with_roles"

    kamal :proxy, :set_config,
      "--publish=false",
      "--options=label=traefik.http.services.kamal_proxy.loadbalancer.server.scheme=http",
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

  private
    def assert_envs(version:)
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

    def vm1_image_ids
      docker_compose("exec vm1 docker image ls -q", capture: true).strip.split("\n")
    end

    def vm1_container_ids
      docker_compose("exec vm1 docker ps -a -q", capture: true).strip.split("\n")
    end

    def assert_no_images_or_containers
      assert vm1_image_ids.empty?
      assert vm1_container_ids.empty?
    end

    def assert_images_and_containers
      assert vm1_image_ids.any?
      assert vm1_container_ids.any?
    end
end
