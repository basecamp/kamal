require "test_helper"
require "active_support/testing/stream"
require "mrsk/cli"

class CliAccessoryTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  test "boot" do
    command = stdouted { Mrsk::Cli::Accessory.start(["boot", "mysql", "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    
    assert_match "Running docker run --name app-mysql -d --restart unless-stopped -p 3306:3306 --volume /var/lib/mysql:/var/lib/mysql --label service=app-mysql mysql:5.7 on 1.1.1.3", command
  end
end
