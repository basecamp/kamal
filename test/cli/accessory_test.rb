require "test_helper"
require "active_support/testing/stream"
require "mrsk/cli"

class CliAccessoryTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  setup    { ENV["MYSQL_ROOT_PASSWORD"] = "secret123" }
  teardown { ENV["MYSQL_ROOT_PASSWORD"] = nil }

  test "upload" do
    command = stdouted { Mrsk::Cli::Accessory.start(["upload", "mysql", "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    
    assert_match "test/fixtures/files/my.cnf app-mysql/etc/mysql/my.cnf", command
  end

  test "boot" do
    command = stdouted { Mrsk::Cli::Accessory.start(["boot", "mysql", "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    
    assert_match "Running docker run --name app-mysql -d --restart unless-stopped -p 3306:3306 -e [REDACTED] -e MYSQL_ROOT_HOST=% --volume /var/lib/mysql:/var/lib/mysql --volume $PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf --label service=app-mysql mysql:5.7 on 1.1.1.3", command
  end
end
