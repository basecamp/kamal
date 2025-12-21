require "test_helper"

class ConfigurationVolumeTest < ActiveSupport::TestCase
  test "docker args absolute" do
    volume = Kamal::Configuration::Volume.new(host_path: "/root/foo/bar", container_path: "/assets")
    assert_equal [ "--volume", "/root/foo/bar:/assets" ], volume.docker_args
  end

  test "docker args relative" do
    volume = Kamal::Configuration::Volume.new(host_path: "foo/bar", container_path: "/assets")
    assert_equal [ "--volume", "$PWD/foo/bar:/assets" ], volume.docker_args
  end

  test "docker args with options" do
    volume = Kamal::Configuration::Volume.new(host_path: "/root/foo/bar", container_path: "/assets", options: "ro")
    assert_equal [ "--volume", "/root/foo/bar:/assets:ro" ], volume.docker_args
  end

  test "docker args with multiple options" do
    volume = Kamal::Configuration::Volume.new(host_path: "/root/foo/bar", container_path: "/assets", options: "ro,z")
    assert_equal [ "--volume", "/root/foo/bar:/assets:ro,z" ], volume.docker_args
  end

  test "docker args with selinux z option" do
    volume = Kamal::Configuration::Volume.new(host_path: "/data", container_path: "/data", options: "z")
    assert_equal [ "--volume", "/data:/data:z" ], volume.docker_args
  end

  test "docker args with selinux Z option" do
    volume = Kamal::Configuration::Volume.new(host_path: "/data", container_path: "/data", options: "Z")
    assert_equal [ "--volume", "/data:/data:Z" ], volume.docker_args
  end
end
