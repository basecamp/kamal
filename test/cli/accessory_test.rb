require "test_helper"
require "active_support/testing/stream"
require "mrsk/cli"

class CliAccessoryTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  setup do
    ENV["VERSION"]             = "999"
    ENV["RAILS_MASTER_KEY"]    = "123"
    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
    ENV.delete("MYSQL_ROOT_PASSWORD")
    ENV.delete("VERSION")
  end

  test "upload" do
    assert_match "test/fixtures/files/my.cnf app-mysql/etc/mysql/my.cnf", run_command("upload", "mysql")
  end

  test "directories" do
    assert_match "mkdir -p $PWD/app-mysql/data", run_command("directories", "mysql")
  end

  test "remove service direcotry" do
    assert_match "rm -rf app-mysql", run_command("remove_service_directory", "mysql")
  end

  test "boot" do
    assert_match "Running docker run --name app-mysql -d --restart unless-stopped -p 3306:3306 -e [REDACTED] -e MYSQL_ROOT_HOST=% --volume $PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf --volume $PWD/app-mysql/data:/var/lib/mysql --label service=app-mysql mysql:5.7 on 1.1.1.3", run_command("boot", "mysql")
  end

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Accessory.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
