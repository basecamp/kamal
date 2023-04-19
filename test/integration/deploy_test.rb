require "net/http"

class DeployTest < ActiveSupport::TestCase

  setup do
    docker_compose "up --build --force-recreate -d"
    sleep 5
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
    def docker_compose(*commands)
      system("cd test/integration && docker compose #{commands.join(" ")}")
    end

    def mrsk(*commands)
      docker_compose("exec deployer mrsk #{commands.join(" ")}")
    end

    def assert_app_is_down
      assert_equal "502", app_response.code
    end

    def assert_app_is_up
      assert_equal "200", app_response.code
    end

    def app_response
      Net::HTTP.get_response(URI.parse("http://localhost:12345"))
    end
end
