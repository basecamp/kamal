require "test_helper"

class CommandsServerTest < ActiveSupport::TestCase
  setup do
    @config = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ],
      builder: { "arch" => "amd64" }
    }
  end

  test "ensure run directory" do
    assert_equal "mkdir -p .kamal", new_command.ensure_run_directory.join(" ")
  end

  private
    def new_command(extra_config = {})
      Kamal::Commands::Server.new(Kamal::Configuration.new(@config.merge(extra_config)))
    end
end
