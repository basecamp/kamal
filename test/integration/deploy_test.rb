require "net/http"
require "test_helper"

class DeployTest < ActiveSupport::TestCase

  setup do
    docker_compose "up --build --force-recreate -d"
    wait_for_healthy
  end

  teardown do
    docker_compose "down -v"
  end

  test "deploy" do
    first_version = latest_app_version

    assert_app_is_down

    mrsk :deploy

    assert_app_is_up version: first_version

    second_version = update_app_rev

    mrsk :redeploy

    assert_app_is_up version: second_version

    mrsk :rollback, first_version

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

  private
    def docker_compose(*commands, capture: false)
      command = "docker compose #{commands.join(" ")}"
      succeeded = false
      if capture
        result = stdouted { succeeded = system("cd test/integration && #{command}") }
      else
        succeeded = system("cd test/integration && #{command}")
      end

      raise "Command `#{command}` failed with error code `#{$?}`" unless succeeded
      result
    end

    def deployer_exec(*commands, **options)
      docker_compose("exec deployer #{commands.join(" ")}", **options)
    end

    def mrsk(*commands, **options)
      deployer_exec(:mrsk, *commands, **options)
    end

    def assert_app_is_down
      assert_equal "502", app_response.code
    end

    def assert_app_is_up(version: nil)
      code = app_response.code
      if code != "200"
        puts "Got response code #{code}, here are the traefik logs:"
        mrsk :traefik, :logs
        puts "And here are the load balancer logs"
        docker_compose :logs, :load_balancer
        puts "Tried to get the response code again and got #{app_response.code}"
      end
      assert_equal "200", code
      assert_app_version(version) if version
    end

    def assert_app_not_found
      assert_equal "404", app_response.code
    end

    def wait_for_app_to_be_up(timeout: 10, up_count: 3)
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

    def app_response
      Net::HTTP.get_response(URI.parse("http://localhost:12345"))
    end

    def update_app_rev
      deployer_exec "./update_app_rev.sh"
      latest_app_version
    end

    def latest_app_version
      deployer_exec("git rev-parse HEAD", capture: true)
    end

    def assert_app_version(version)
      actual_version = Net::HTTP.get_response(URI.parse("http://localhost:12345/version")).body.strip

      assert_equal version, actual_version
    end

    def wait_for_healthy(timeout: 20)
      timeout_at = Time.now + timeout
      while docker_compose("ps -a | tail -n +2 | grep -v '(healthy)' | wc -l", capture: true) != "0"
        if timeout_at < Time.now
          docker_compose("ps -a | tail -n +2 | grep -v '(healthy)'")
          raise "Container not healthy after #{timeout} seconds" if timeout_at < Time.now
        end
        sleep 0.1
      end
    end
end
