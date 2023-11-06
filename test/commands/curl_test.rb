require "test_helper"

class CommandsCurlTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ]
    }
    @curl = Kamal::Commands::Curl.new(Kamal::Configuration.new(@config))
  end

  test "install" do
    assert_equal "apt-get --assume-yes install curl", @curl.install.join(" ")
  end

  test "installed?" do
    assert_equal "curl --version", @curl.installed?.join(" ")
  end

  test "is_installable_with_apt?" do
    assert_equal "cat \"/etc/debian_version\"", @curl.installed?.join(" ")
  end

end
