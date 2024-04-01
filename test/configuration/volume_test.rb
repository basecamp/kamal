require "test_helper"

class ConfigurationVolumeTest < ActiveSupport::TestCase
  test "docker args absolute" do
    volume = Kamal::Configuration::Volume.new(host_path: "/root/foo/bar", container_path: "/assets")
    assert_equal [ "--volume", "/root/foo/bar:/assets" ], volume.docker_args
  end

  test "docker args relative" do
    volume = Kamal::Configuration::Volume.new(host_path: "foo/bar", container_path: "/assets")
    assert_equal [ "--volume", "$(pwd)/foo/bar:/assets" ], volume.docker_args
  end
end
