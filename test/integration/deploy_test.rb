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
    assert_app_is_down

    mrsk :deploy

    assert_app_is_up
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

    def deployer_exec(*commands, capture: false)
      if capture
        stdouted { docker_compose("exec deployer #{commands.join(" ")}") }
      else
        docker_compose("exec deployer #{commands.join(" ")}", capture: capture)
      end
    end

    def mrsk(*commands, capture: false)
      deployer_exec(:mrsk, *commands, capture: capture)
    end

    def assert_app_is_down
      assert_equal "502", app_response.code
    end

    def assert_app_is_up
      code = app_response.code
      if code != "200"
        puts "Got response code #{code}, here are the traefik logs:"
        mrsk :traefik, :logs
        puts "And here are the load balancer logs"
        docker_compose :logs, :load_balancer
        puts "Tried to get the response code again and got #{app_response.code}"
      end
      assert_equal "200", code
    end

    def app_response
      Net::HTTP.get_response(URI.parse("http://localhost:12345"))
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
