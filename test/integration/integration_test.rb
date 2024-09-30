require "net/http"
require "test_helper"

class IntegrationTest < ActiveSupport::TestCase
  setup do
    ENV["TEST_ID"] = SecureRandom.hex
    docker_compose "up --build -d"
    wait_for_healthy
    setup_deployer
    @app = "app"
  end

  teardown do
    unless passed?
      [ :deployer, :vm1, :vm2, :shared, :load_balancer, :registry ].each do |container|
        puts
        puts "Logs for #{container}:"
        docker_compose :logs, container
      end
    end
    docker_compose "down -t 1"
  end

  private
    def docker_compose(*commands, capture: false, raise_on_error: true)
      command = "TEST_ID=#{ENV["TEST_ID"]} docker compose #{commands.join(" ")}"
      succeeded = false
      if capture
        result = stdouted { succeeded = system("cd test/integration && #{command}") }
      else
        succeeded = system("cd test/integration && #{command}")
      end

      raise "Command `#{command}` failed with error code `#{$?}`, and output:\n#{result}" if !succeeded && raise_on_error
      result
    end

    def deployer_exec(*commands, workdir: nil, **options)
      workdir ||= "/#{@app}"
      docker_compose("exec --workdir #{workdir} deployer #{commands.join(" ")}", **options)
    end

    def kamal(*commands, **options)
      deployer_exec(:kamal, *commands, **options)
    end

    def assert_app_is_down
      response = app_response
      debug_response_code(response, "502")
      assert_equal "502", response.code
    end

    def assert_app_not_found
      response = app_response
      debug_response_code(response, "404")
      assert_equal "404", response.code
    end

    def assert_app_is_up(version: nil, app: @app)
      response = app_response(app: app)
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

    def app_response(app: @app)
      Net::HTTP.get_response(URI.parse("http://#{app_host(app)}:12345/version"))
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

    def wait_for_healthy(timeout: 30)
      timeout_at = Time.now + timeout
      while docker_compose("ps -a | tail -n +2 | grep -v '(healthy)' | wc -l", capture: true) != "0"
        if timeout_at < Time.now
          docker_compose("ps -a | tail -n +2 | grep -v '(healthy)'")
          raise "Container not healthy after #{timeout} seconds" if timeout_at < Time.now
        end
        sleep 0.1
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
end
