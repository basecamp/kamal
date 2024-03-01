require "test_helper"

class ConfigurationVolumesFilesAndDirectoriesTest < ActiveSupport::TestCase
  setup do
    @deploy = {
      service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" },
      servers: {
        "web" => [ "1.1.1.1", "1.1.1.2" ],
      },
      traefik: {
        "files" => [
          "config/traefik.yaml:/etc/traefik/traefik.yaml",
        ],
        "directories" => [
          "config/traefik.d:/etc/traefik/traefik.d"
        ],
        "volumes" => [
          "/mnt/certs:/etc/traefik/certs"
        ],
      },
      accessories: {
        "mysql" => {
          "files" => [
            "config/mysql/my.cnf:/etc/mysql/my.cnf",
            "db/structure.sql:/docker-entrypoint-initdb.d/structure.sql"
          ],
          "directories" => [
            "data:/var/lib/mysql"
          ]
        },
        "redis" => {
          "volumes" => [
            "/var/lib/redis:/data"
          ],

        }
      }
    }

    @config = Kamal::Configuration.new(@deploy)
    @traefik = Kamal::Commands::Traefik.new(@config)
  end


  test "volume args for accessories" do
    assert_equal ["--volume", "$PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf", "--volume", "$PWD/app-mysql/docker-entrypoint-initdb.d/structure.sql:/docker-entrypoint-initdb.d/structure.sql", "--volume", "$PWD/app-mysql/data:/var/lib/mysql"], @config.accessory(:mysql).volume_args
    assert_equal ["--volume", "/var/lib/redis:/data"], @config.accessory(:redis).volume_args
  end

  test "volume args for traefik" do
    assert_equal ["--volume", "/mnt/certs:/etc/traefik/certs", "--volume", "$PWD/traefik/etc/traefik/traefik.yaml:/etc/traefik/traefik.yaml", "--volume", "$PWD/traefik/config/traefik.d:/etc/traefik/traefik.d"], @traefik.volume_args
  end
end
