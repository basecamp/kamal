require "test_helper"

class ConfigurationAccessoryTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: [ "1.1.1.1", "1.1.1.2" ],
      env: { "REDIS_URL" => "redis://x/y" },
      accessories: {
        "mysql" => {
          "image" => "mysql:8.0",
          "host" => "1.1.1.5",
          "port" => "3306",
          "env" => {
            "clear" => {
              "MYSQL_ROOT_HOST" => "%"
            },
            "secret" => [
              "MYSQL_ROOT_PASSWORD"
            ],
          },
          "files" => [
            "config/mysql/my.cnf:/etc/mysql/my.cnf",
            "db/structure.sql:/docker-entrypoint-initdb.d/structure.sql"
          ],
          "directories" => [
            "data:/var/lib/mysql"
          ]
        },
        "redis" => {
          "image" => "redis:latest",
          "host" => "1.1.1.6",
          "port" => "6379:6379",
          "labels" => {
            "cache" => true
          },
          "env" => {
            "SOMETHING" => "else"
          },
          "volumes" => [
            "/var/lib/redis:/data"
          ]
        }
      }
    }

    @config = Mrsk::Configuration.new(@deploy)
  end

  test "service name" do
    assert_equal "app-mysql", @config.accessory(:mysql).service_name
    assert_equal "app-redis", @config.accessory(:redis).service_name
  end

  test "port" do
    assert_equal "3306:3306", @config.accessory(:mysql).port
    assert_equal "6379:6379", @config.accessory(:redis).port
  end

  test "host" do
    assert_equal "1.1.1.5", @config.accessory(:mysql).host
    assert_equal "1.1.1.6", @config.accessory(:redis).host
  end

  test "missing host" do
    assert_raises(Mrsk::Configuration::Error) do
      @deploy[:accessories]["mysql"]["host"] = nil
      @config = Mrsk::Configuration.new(@deploy)
      @config.accessory(:mysql).host
    end
  end

  test "label args" do
    assert_equal ["--label", "service=\"app-mysql\""], @config.accessory(:mysql).label_args
    assert_equal ["--label", "service=\"app-redis\"", "--label", "cache=\"true\""], @config.accessory(:redis).label_args
  end

  test "env args with secret" do
    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
    assert_equal ["-e", "MYSQL_ROOT_PASSWORD=\"secret123\"", "-e", "MYSQL_ROOT_HOST=\"%\""], @config.accessory(:mysql).env_args
    assert @config.accessory(:mysql).env_args[1].is_a?(SSHKit::Redaction)
  ensure
    ENV["MYSQL_ROOT_PASSWORD"] = nil
  end

  test "env args without secret" do
    assert_equal ["-e", "SOMETHING=\"else\""], @config.accessory(:redis).env_args
  end

  test "volume args" do
    assert_equal ["--volume", "$PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf", "--volume", "$PWD/app-mysql/docker-entrypoint-initdb.d/structure.sql:/docker-entrypoint-initdb.d/structure.sql", "--volume", "$PWD/app-mysql/data:/var/lib/mysql"], @config.accessory(:mysql).volume_args
    assert_equal ["--volume", "/var/lib/redis:/data"], @config.accessory(:redis).volume_args
  end

  test "dynamic file expansion" do
    @deploy[:accessories]["mysql"]["files"] << "test/fixtures/files/structure.sql.erb:/docker-entrypoint-initdb.d/structure.sql"
    @config = Mrsk::Configuration.new(@deploy)

    assert_match "This was dynamically expanded", @config.accessory(:mysql).files.keys[2].read
    assert_match "%", @config.accessory(:mysql).files.keys[2].read
  end

  test "directories" do
    assert_equal({"$PWD/app-mysql/data"=>"/var/lib/mysql"}, @config.accessory(:mysql).directories)
  end
end
