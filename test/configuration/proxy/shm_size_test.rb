require "test_helper"

class ConfigurationProxyShmSizeTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      builder: { "arch" => "amd64" }, servers: [ "1.1.1.1" ]
    }
  end

  test "shm_size defined" do
    @deploy[:proxy] = { "shm_size" => "123mb" }
    assert_equal config.proxy.shm_size, "123mb"
  end

  test "shm_size not defined" do
    assert_nil config.proxy.shm_size
  end

  private
    def config
      Kamal::Configuration.new(@deploy)
    end
end
