require "net/http"
require "digest"
require "base64"
require "json"
require "test_helper"

class IntegrationTest < ActiveSupport::TestCase
  # Stable per-worktree Compose project name: the same across repeated runs in a given
  # worktree (so `down` still tears down the right stack), but unique across worktrees
  # so two suites can run concurrently without clashing on container/network/volume names.
  COMPOSE_PROJECT = "kamal-test-#{Digest::SHA256.hexdigest(File.expand_path("../..", __dir__))[0, 8]}"

  setup do
    ENV["TEST_ID"] = SecureRandom.hex
    authenticate_hub_cache
    compose_up_with_retry
    wait_for_healthy
    setup_deployer
    deployer_exec("sh -c 'rm -f /tmp/otel/*.json /tmp/kamal-deploy-logs/*'", workdir: "/")
    # Host ports are published on ephemeral ports (collision-free across worktrees);
    # discover the ones Compose actually assigned.
    @http_port = published_port("load_balancer", 80)
    @https_port = published_port("vm1", 443)
    @app = "app"
  end

  teardown do
    if !passed? && ENV["DEBUG_CONTAINER_LOGS"]
      [ :deployer, :vm1, :vm2, :shared, :load_balancer, :registry ].each do |container|
        puts
        puts "Logs for #{container}:"
        docker_compose :logs, container
      end
    end
    docker_compose "down -t 0"
  end

  private
    def docker_compose(*commands, capture: false, raise_on_error: true)
      command = "TEST_ID=#{ENV["TEST_ID"]} COMPOSE_PROJECT_NAME=#{COMPOSE_PROJECT} docker compose #{commands.join(" ")}"
      succeeded = false
      if capture || !ENV["DEBUG"]
        result = stdouted { stderred { succeeded = system("cd test/integration && #{command}") } }
      else
        succeeded = system("cd test/integration && #{command}")
      end

      raise "Command `#{command}` failed with error code `#{$?}`, and output:\n#{result}" if !succeeded && raise_on_error
      result
    end

    # The hub-cache pull-through cache fetches from Docker Hub on its own, and Hub's
    # anonymous pull limit is per-IP — easily exhausted by the suite. Reuse the
    # developer's existing `docker login` so the cache authenticates its upstream
    # pulls against their account quota. Respects DOCKERHUB_USERNAME/DOCKERHUB_TOKEN
    # if already set (e.g. in CI); a no-op if no login is found (stays anonymous).
    def authenticate_hub_cache
      return if ENV["DOCKERHUB_TOKEN"].to_s.present?
      username, token = docker_hub_credentials
      return unless token.present?
      ENV["DOCKERHUB_USERNAME"] = username
      ENV["DOCKERHUB_TOKEN"] = token
    end

    def docker_hub_credentials
      config_path = File.expand_path("~/.docker/config.json")
      return [ nil, nil ] unless File.exist?(config_path)

      config = JSON.parse(File.read(config_path))
      registry = "https://index.docker.io/v1/"

      if (helper = config.dig("credHelpers", registry) || config["credsStore"]).present?
        creds = JSON.parse(`echo #{registry} | docker-credential-#{helper} get 2>/dev/null`)
        [ creds["Username"], creds["Secret"] ]
      elsif (auth = config.dig("auths", registry, "auth")).present?
        Base64.decode64(auth).split(":", 2)
      else
        [ nil, nil ]
      end
    rescue
      [ nil, nil ]
    end

    # Returns the ephemeral host port Compose assigned to a service's container port,
    # e.g. published_port("load_balancer", 80) => 32768.
    def published_port(service, container_port)
      docker_compose("port #{service} #{container_port}", capture: true)
        .lines.first.to_s.strip.split(":").last.to_i
    end

    def deployer_exec(*commands, workdir: nil, **options)
      workdir ||= "/#{@app}"
      docker_compose("exec --workdir #{workdir} deployer #{commands.join(" ")}", **options)
    end

    def kamal(*commands, **options)
      deployer_exec(:kamal, *commands, **options)
    end

    def assert_app_is_down
      assert_app_error_code("502")
    end

    def assert_app_in_maintenance(message: nil)
      assert_app_error_code("503", message: message)
    end

    def assert_app_not_found
      assert_app_error_code("404")
    end

    def assert_app_error_code(code, message: nil)
      response = app_response
      debug_response_code(response, code)
      assert_equal code, response.code
      assert_match message, response.body.strip if message
    end

    def assert_app_is_up(version: nil, app: @app, cert: nil)
      response = app_response(app: app, cert: cert)
      debug_response_code(response, "200")
      assert_equal "200", response.code
      assert_app_version(version, response) if version
    end

    def wait_for_app_to_be_up(timeout: 20, up_count: 3)
      timeout_at = Time.now + timeout
      up_times = 0
      response = app_response
      while up_times < up_count && timeout_at > Time.now
        sleep 0.1
        up_times += 1 if response.code == "200"
        response = app_response
      end
      assert_equal up_times, up_count
    end

    def app_response(app: @app, cert: nil)
      uri = cert ? URI.parse("https://#{app_host(app)}:#{@https_port}/version") : URI.parse("http://#{app_host(app)}:#{@http_port}/version")

      if cert
        https_response_with_cert(uri, cert)
      else
        Net::HTTP.get_response(uri)
      end
    end

    def update_app_rev
      deployer_exec "./update_app_rev.sh #{@app}", workdir: "/"
      latest_app_version
    end

    def break_app
      deployer_exec "./break_app.sh #{@app}", workdir: "/"
      latest_app_version
    end

    def latest_app_version
      deployer_exec("git rev-parse HEAD", capture: true)
    end

    def assert_app_version(version, response)
      assert_equal version, response.body.strip
    end

    def assert_hooks_ran(*hooks)
      hooks.each do |hook|
        file = "/tmp/#{ENV["TEST_ID"]}/#{hook}"
        assert_equal "removed '#{file}'", deployer_exec("rm -v #{file}", capture: true).strip
      end
    end

    def assert_200(response)
      code = response.code
      if code != "200"
        puts "Got response code #{code}, here are the proxy logs:"
        kamal :proxy, :logs
        puts "And here are the load balancer logs"
        docker_compose :logs, :load_balancer
        puts "Tried to get the response code again and got #{app_response.code}"
      end
      assert_equal "200", code
    end

    def compose_up_with_retry
      build_images_once
      docker_compose "up -d --no-build"
    rescue RuntimeError => e
      raise if @compose_up_retried
      @compose_up_retried = true
      puts "compose up failed, retrying once: #{e.message.lines.first&.strip}"
      docker_compose "down -t 0", raise_on_error: false
      retry
    end

    def build_images_once
      return if $IMAGES_BUILT
      docker_compose "build"
      $IMAGES_BUILT = true
    end

    def wait_for_healthy(timeout: 30)
      timeout_at = Time.now + timeout
      loop do
        containers = container_statuses

        break if containers.all? { |c| c["Health"] == "healthy" }

        broken = containers.select do |c|
          c["Health"] == "unhealthy" || %w[ exited dead restarting ].include?(c["State"])
        end
        if broken.any?
          dump_container_logs(broken)
          raise "Container hard error (retry will not help): #{describe_containers(broken)}"
        end

        if timeout_at < Time.now
          starting = containers.reject { |c| c["Health"] == "healthy" }
          dump_container_logs(starting)
          raise "Container not healthy after #{timeout} seconds (slow boot, retry may help): #{describe_containers(starting)}"
        end
        sleep 0.1
      end
    end

    def container_statuses
      output = docker_compose("ps -a --format json", capture: true).strip
      return [] if output.empty?

      if output.start_with?("[")
        JSON.parse(output)
      else
        output.lines.map { |line| JSON.parse(line) }
      end
    end

    def describe_containers(containers)
      containers.map { |c| "#{c["Service"]} (state=#{c["State"]} health=#{c["Health"]} exit=#{c["ExitCode"]})" }.join(", ")
    end

    def dump_container_logs(containers)
      containers.each do |c|
        puts
        puts "=== #{c["Service"]} (state=#{c["State"]} health=#{c["Health"]} exit=#{c["ExitCode"]}) ==="
        puts docker_compose("logs --no-color --tail 50 #{c["Service"]}", capture: true, raise_on_error: false)
      end
    end

    def setup_deployer
      deployer_exec("./setup.sh", workdir: "/") unless $DEPLOYER_SETUP
      $DEPLOYER_SETUP = true
    end

    def debug_response_code(app_response, expected_code)
      code = app_response.code
      if code != expected_code
        puts "Got response code #{code}, here are the proxy logs:"
        kamal :proxy, :logs
        puts "And here are the load balancer logs"
        docker_compose :logs, :load_balancer
        puts "Tried to get the response code again and got #{app_response.code}"
      end
    end

    def assert_container_running(host:, name:)
      assert container_running?(host: host, name: name)
    end

    def assert_container_not_running(host:, name:)
      assert_not container_running?(host: host, name: name)
    end

    def container_running?(host:, name:)
      docker_compose("exec #{host} docker ps --filter=name=#{name} | tail -n+2", capture: true).strip.present?
    end

    def assert_app_directory_removed
      assert_directory_removed("./kamal/apps/#{@app}")
    end

    def assert_directory_removed(directory)
      assert docker_compose("exec vm1 ls #{directory} | wc -l", capture: true).strip == "0"
    end

    def assert_proxy_running
      assert_container_running(host: "vm1", name: "kamal-proxy")
    end

    def assert_proxy_not_running
      assert_container_not_running(host: "vm1", name: "kamal-proxy")
    end

    def app_host(app = @app)
      case app
      when "app"
        "127.0.0.1"
      else
        "localhost"
      end
    end

    def deploy_log_content(pattern)
      deployer_exec("sh -c 'cat /tmp/kamal-deploy-logs/#{pattern}'", capture: true)
        .gsub(/\e\[[0-9;]*m/, "")
    end

    def otel_payloads
      files = deployer_exec("sh -c 'ls /tmp/otel/*.json'", capture: true).strip.split("\n")
      files.map { |f| JSON.parse(deployer_exec("cat #{f}", capture: true)) }
    end

    def otel_log_records
      otel_payloads.flat_map { |p| p.dig("resourceLogs", 0, "scopeLogs", 0, "logRecords") || [] }
    end

    def otel_events
      otel_log_records.select { |r| r["eventName"].present? }
    end

    def wait_for_otel_events(expected:, timeout: 3)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        events = otel_events
        return events if events.length >= expected
        return events if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 0.1
      end
    end

    def otel_resource_attributes
      attrs = otel_payloads.first&.dig("resourceLogs", 0, "resource", "attributes") || []
      attrs.to_h { |a| [ a["key"], a.dig("value", "stringValue") ] }
    end

    def https_response_with_cert(uri, cert)
      host = uri.host
      port = uri.port

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      store = OpenSSL::X509::Store.new
      store.add_cert(OpenSSL::X509::Certificate.new(File.read(cert)))
      http.cert_store = store

      request = Net::HTTP::Get.new(uri)
      http.request(request)
    end
end
