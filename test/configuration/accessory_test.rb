require "test_helper"

class ConfigurationAccessoryTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: {
        "web" => [ "1.1.1.1", "1.1.1.2" ],
        "workers" => [ "1.1.1.3", "1.1.1.4" ]
      },
      builder: { "arch" => "amd64" },
      env: { "VALKEY_URL" => "valkey://x/y" },
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
            ]
          },
          "files" => [
            "config/mysql/my.cnf:/etc/mysql/my.cnf",
            "db/structure.sql:/docker-entrypoint-initdb.d/structure.sql"
          ],
          "directories" => [
            "data:/var/lib/mysql"
          ]
        },
        "valkey" => {
          "image" => "valkey/valkey:latest",
          "hosts" => [ "1.1.1.6", "1.1.1.7" ],
          "port" => "6379:6379",
          "labels" => {
            "cache" => "true"
          },
          "env" => {
            "SOMETHING" => "else"
          },
          "volumes" => [
            "/var/lib/valkey:/data"
          ],
          "options" => {
            "cpus" => "4",
            "memory" => "2GB"
          }
        },
        "monitoring" => {
          "service" => "custom-monitoring",
          "image" => "monitoring:latest",
          "roles" => [ "web" ],
          "port" => "4321:4321",
          "labels" => {
            "cache" => "true"
          },
          "env" => {
            "STATSD_PORT" => "8126"
          },
          "options" => {
            "cpus" => "4",
            "memory" => "2GB"
          }
        }
      }
    }

    @config = Kamal::Configuration.new(@deploy)
  end

  test "service name" do
    assert_equal "app-mysql", @config.accessory(:mysql).service_name
    assert_equal "app-valkey", @config.accessory(:valkey).service_name
    assert_equal "custom-monitoring", @config.accessory(:monitoring).service_name
  end

  test "port" do
    assert_equal "3306:3306", @config.accessory(:mysql).port
    assert_equal "6379:6379", @config.accessory(:valkey).port
  end

  test "host" do
    assert_equal [ "1.1.1.5" ], @config.accessory(:mysql).hosts
    assert_equal [ "1.1.1.6", "1.1.1.7" ], @config.accessory(:valkey).hosts
    assert_equal [ "1.1.1.1", "1.1.1.2" ], @config.accessory(:monitoring).hosts
  end

  test "missing host" do
    @deploy[:accessories]["mysql"]["host"] = nil

    assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new(@deploy)
    end
  end

  test "setting host, hosts and roles" do
    @deploy[:accessories]["mysql"]["hosts"] = [ "mysql-db1" ]
    @deploy[:accessories]["mysql"]["roles"] = [ "db" ]

    exception = assert_raises(Kamal::ConfigurationError) do
      Kamal::Configuration.new(@deploy)
    end
    assert_equal "accessories/mysql: specify one of `host`, `hosts` or `roles`", exception.message
  end

  test "all hosts" do
    assert_equal [ "1.1.1.1", "1.1.1.2", "1.1.1.3", "1.1.1.4", "1.1.1.5", "1.1.1.6", "1.1.1.7" ], @config.all_hosts
  end

  test "label args" do
    assert_equal [ "--label", "service=\"app-mysql\"" ], @config.accessory(:mysql).label_args
    assert_equal [ "--label", "service=\"app-valkey\"", "--label", "cache=\"true\"" ], @config.accessory(:valkey).label_args
  end

  test "env args" do
    with_test_secrets("secrets" => "MYSQL_ROOT_PASSWORD=secret123") do
      config = Kamal::Configuration.new(@deploy)

      assert_equal [ "--env", "MYSQL_ROOT_HOST=\"%\"", "--env-file", ".kamal/apps/app/env/accessories/mysql.env" ], config.accessory(:mysql).env_args.map(&:to_s)
      assert_equal "MYSQL_ROOT_PASSWORD=secret123\n", config.accessory(:mysql).secrets_io.string
      assert_equal [ "--env", "SOMETHING=\"else\"", "--env-file", ".kamal/apps/app/env/accessories/valkey.env" ], @config.accessory(:valkey).env_args
      assert_equal "\n", config.accessory(:valkey).secrets_io.string
    end
  end

  test "volume args" do
    assert_equal [ "--volume", "$PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf", "--volume", "$PWD/app-mysql/docker-entrypoint-initdb.d/structure.sql:/docker-entrypoint-initdb.d/structure.sql", "--volume", "$PWD/app-mysql/data:/var/lib/mysql" ], @config.accessory(:mysql).volume_args
    assert_equal [ "--volume", "/var/lib/valkey:/data" ], @config.accessory(:valkey).volume_args
  end

  test "dynamic file expansion" do
    @deploy[:accessories]["mysql"]["files"] << "test/fixtures/files/structure.sql.erb:/docker-entrypoint-initdb.d/structure.sql"
    @config = Kamal::Configuration.new(@deploy)

    assert_match "This was dynamically expanded", @config.accessory(:mysql).files.keys[2].read
    assert_match "%", @config.accessory(:mysql).files.keys[2].read
  end

  test "directory with a relative path" do
    @deploy[:accessories]["mysql"]["directories"] = [ "data:/var/lib/mysql" ]
    assert_equal({ "$PWD/app-mysql/data"=>"/var/lib/mysql" }, @config.accessory(:mysql).directories)
  end

  test "directory with an absolute path" do
    @deploy[:accessories]["mysql"]["directories"] = [ "/var/data/mysql:/var/lib/mysql" ]
    assert_equal({ "/var/data/mysql"=>"/var/lib/mysql" }, @config.accessory(:mysql).directories)
  end

  test "options" do
    assert_equal [ "--cpus", "\"4\"", "--memory", "\"2GB\"" ], @config.accessory(:valkey).option_args
  end
end
