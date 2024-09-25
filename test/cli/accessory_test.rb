require_relative "cli_test_case"

class CliAccessoryTest < CliTestCase
  setup do
    setup_test_secrets("secrets" => "MYSQL_ROOT_PASSWORD=secret")
  end

  teardown do
    teardown_test_secrets
  end

  test "boot" do
    Kamal::Cli::Accessory.any_instance.expects(:directories).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:upload).with("mysql")

    run_command("boot", "mysql").tap do |output|
      assert_match /docker login.*on 1.1.1.3/, output
      assert_match "docker run --name app-mysql --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 3306:3306 --env MYSQL_ROOT_HOST=\"%\" --env-file .kamal/apps/app/env/accessories/mysql.env --volume $PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf --volume $PWD/app-mysql/data:/var/lib/mysql --label service=\"app-mysql\" mysql:5.7 on 1.1.1.3", output
    end
  end

  test "boot all" do
    Kamal::Cli::Accessory.any_instance.expects(:directories).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:upload).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:directories).with("redis")
    Kamal::Cli::Accessory.any_instance.expects(:upload).with("redis")

    run_command("boot", "all").tap do |output|
      assert_match /docker login.*on 1.1.1.3/, output
      assert_match /docker login.*on 1.1.1.1/, output
      assert_match /docker login.*on 1.1.1.2/, output
      assert_match /docker network create kamal.*on 1.1.1.1/, output
      assert_match /docker network create kamal.*on 1.1.1.2/, output
      assert_match /docker network create kamal.*on 1.1.1.3/, output
      assert_match "docker run --name app-mysql --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 3306:3306 --env MYSQL_ROOT_HOST=\"%\" --env-file .kamal/apps/app/env/accessories/mysql.env --volume $PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf --volume $PWD/app-mysql/data:/var/lib/mysql --label service=\"app-mysql\" mysql:5.7 on 1.1.1.3", output
      assert_match "docker run --name app-redis --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 6379:6379 --env-file .kamal/apps/app/env/accessories/redis.env --volume $PWD/app-redis/data:/data --label service=\"app-redis\" redis:latest on 1.1.1.1", output
      assert_match "docker run --name app-redis --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 6379:6379 --env-file .kamal/apps/app/env/accessories/redis.env --volume $PWD/app-redis/data:/data --label service=\"app-redis\" redis:latest on 1.1.1.2", output
    end
  end

  test "upload" do
    run_command("upload", "mysql").tap do |output|
      assert_match "mkdir -p app-mysql/etc/mysql", output
      assert_match "test/fixtures/files/my.cnf to app-mysql/etc/mysql/my.cnf", output
      assert_match "chmod 755 app-mysql/etc/mysql/my.cnf", output
    end
  end

  test "directories" do
    assert_match "mkdir -p $PWD/app-mysql/data", run_command("directories", "mysql")
  end

  test "reboot" do
    Kamal::Commands::Registry.any_instance.expects(:login)
    Kamal::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:remove_container).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:boot).with("mysql", prepare: false)

    run_command("reboot", "mysql")
  end

  test "reboot all" do
    Kamal::Commands::Registry.any_instance.expects(:login).times(3)
    Kamal::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:remove_container).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:boot).with("mysql", prepare: false)
    Kamal::Cli::Accessory.any_instance.expects(:stop).with("redis")
    Kamal::Cli::Accessory.any_instance.expects(:remove_container).with("redis")
    Kamal::Cli::Accessory.any_instance.expects(:boot).with("redis", prepare: false)

    run_command("reboot", "all")
  end

  test "start" do
    assert_match "docker container start app-mysql", run_command("start", "mysql")
  end

  test "stop" do
    assert_match "docker container stop app-mysql", run_command("stop", "mysql")
  end

  test "restart" do
    Kamal::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:start).with("mysql")

    run_command("restart", "mysql")
  end

  test "details" do
    run_command("details", "mysql").tap do |output|
      assert_match "docker ps --filter label=service=app-mysql", output
      assert_match "Accessory mysql Host: 1.1.1.3", output
    end
  end

  test "details with non-existent accessory" do
    assert_equal "No accessory by the name of 'hello' (options: mysql and redis)", stderred { run_command("details", "hello") }
  end

  test "details with all" do
    run_command("details", "all").tap do |output|
      assert_match "Accessory mysql Host: 1.1.1.3", output
      assert_match "Accessory redis Host: 1.1.1.2", output
      assert_match "docker ps --filter label=service=app-mysql", output
      assert_match "docker ps --filter label=service=app-redis", output
    end
  end

  test "exec" do
    run_command("exec", "mysql", "mysql -v").tap do |output|
      assert_match "Launching command from new container", output
      assert_match "mysql -v", output
    end
  end

  test "exec with reuse" do
    run_command("exec", "mysql", "--reuse", "mysql -v").tap do |output|
      assert_match "Launching command from existing container", output
      assert_match "docker exec app-mysql mysql -v", output
    end
  end

  test "logs" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.3 'docker logs app-mysql --timestamps --tail 10 2>&1'")

    assert_match "docker logs app-mysql  --tail 100 --timestamps 2>&1", run_command("logs", "mysql")
  end

  test "logs with grep" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.3 'docker logs app-mysql --timestamps 2>&1 | grep \'hey\''")

    assert_match "docker logs app-mysql --timestamps 2>&1 | grep 'hey'", run_command("logs", "mysql", "--grep", "hey")
  end

  test "logs with grep and grep options" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.3 'docker logs app-mysql --timestamps 2>&1 | grep \'hey\' -C 2'")

    assert_match "docker logs app-mysql --timestamps 2>&1 | grep 'hey' -C 2", run_command("logs", "mysql", "--grep", "hey", "--grep-options", "-C 2")
  end

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.3 -p 22 'docker logs app-mysql --timestamps --tail 10 --follow 2>&1'")

    assert_match "docker logs app-mysql --timestamps --tail 10 --follow 2>&1", run_command("logs", "mysql", "--follow")
  end

  test "logs with follow and grep" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.3 -p 22 'docker logs app-mysql --timestamps --tail 10 --follow 2>&1 | grep \"hey\"'")

    assert_match "docker logs app-mysql --timestamps --tail 10 --follow 2>&1 | grep \"hey\"", run_command("logs", "mysql", "--follow", "--grep", "hey")
  end

  test "logs with follow, grep, and grep options" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.3 -p 22 'docker logs app-mysql --timestamps --tail 10 --follow 2>&1 | grep \"hey\" -C 2'")

    assert_match "docker logs app-mysql --timestamps --tail 10 --follow 2>&1 | grep \"hey\" -C 2", run_command("logs", "mysql", "--follow", "--grep", "hey", "--grep-options", "-C 2")
  end

  test "remove with confirmation" do
    Kamal::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:remove_container).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:remove_image).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:remove_service_directory).with("mysql")

    run_command("remove", "mysql", "-y")
  end

  test "remove all with confirmation" do
    Kamal::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:remove_container).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:remove_image).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:remove_service_directory).with("mysql")
    Kamal::Cli::Accessory.any_instance.expects(:stop).with("redis")
    Kamal::Cli::Accessory.any_instance.expects(:remove_container).with("redis")
    Kamal::Cli::Accessory.any_instance.expects(:remove_image).with("redis")
    Kamal::Cli::Accessory.any_instance.expects(:remove_service_directory).with("redis")

    run_command("remove", "all", "-y")
  end

  test "remove_container" do
    assert_match "docker container prune --force --filter label=service=app-mysql", run_command("remove_container", "mysql")
  end

  test "remove_image" do
    assert_match "docker image rm --force mysql", run_command("remove_image", "mysql")
  end

  test "remove_service_directory" do
    assert_match "rm -rf app-mysql", run_command("remove_service_directory", "mysql")
  end

  test "hosts param respected" do
    Kamal::Cli::Accessory.any_instance.expects(:directories).with("redis")
    Kamal::Cli::Accessory.any_instance.expects(:upload).with("redis")

    run_command("boot", "redis", "--hosts", "1.1.1.1").tap do |output|
      assert_match /docker login.*on 1.1.1.1/, output
      assert_no_match /docker login.*on 1.1.1.2/, output
      assert_match "docker run --name app-redis --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 6379:6379 --env-file .kamal/apps/app/env/accessories/redis.env --volume $PWD/app-redis/data:/data --label service=\"app-redis\" redis:latest on 1.1.1.1", output
      assert_no_match "docker run --name app-redis --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 6379:6379 --env-file .kamal/apps/app/env/accessories/redis.env --volume $PWD/app-redis/data:/data --label service=\"app-redis\" redis:latest on 1.1.1.2", output
    end
  end

  test "hosts param intersected with configuration" do
    Kamal::Cli::Accessory.any_instance.expects(:directories).with("redis")
    Kamal::Cli::Accessory.any_instance.expects(:upload).with("redis")

    run_command("boot", "redis", "--hosts", "1.1.1.1,1.1.1.3").tap do |output|
      assert_match /docker login.*on 1.1.1.1/, output
      assert_no_match /docker login.*on 1.1.1.3/, output
      assert_match "docker run --name app-redis --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 6379:6379 --env-file .kamal/apps/app/env/accessories/redis.env --volume $PWD/app-redis/data:/data --label service=\"app-redis\" redis:latest on 1.1.1.1", output
      assert_no_match "docker run --name app-redis --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 6379:6379 --env-file .kamal/apps/app/env/accessories/redis.env --volume $PWD/app-redis/data:/data --label service=\"app-redis\" redis:latest on 1.1.1.3", output
    end
  end

  test "upgrade" do
    run_command("upgrade", "-y", "all").tap do |output|
      assert_match "Upgrading all accessories on 1.1.1.3,1.1.1.1,1.1.1.2...", output
      assert_match "docker network create kamal on 1.1.1.3", output
      assert_match "docker container stop app-mysql on 1.1.1.3", output
      assert_match "docker run --name app-mysql --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 3306:3306 --env MYSQL_ROOT_HOST="%" --env-file .kamal/apps/app/env/accessories/mysql.env --volume $PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf --volume $PWD/app-mysql/data:/var/lib/mysql --label service=\"app-mysql\" mysql:5.7 on 1.1.1.3", output
      assert_match "Upgraded all accessories on 1.1.1.3,1.1.1.1,1.1.1.2...", output
    end
  end

  test "upgrade rolling" do
    run_command("upgrade", "--rolling", "-y", "all").tap do |output|
      assert_match "Upgrading all accessories on 1.1.1.3...", output
      assert_match "docker network create kamal on 1.1.1.3", output
      assert_match "docker container stop app-mysql on 1.1.1.3", output
      assert_match "docker run --name app-mysql --detach --restart unless-stopped --network kamal --log-opt max-size=\"10m\" --publish 3306:3306 --env MYSQL_ROOT_HOST="%" --env-file .kamal/apps/app/env/accessories/mysql.env --volume $PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf --volume $PWD/app-mysql/data:/var/lib/mysql --label service=\"app-mysql\" mysql:5.7 on 1.1.1.3", output
      assert_match "Upgraded all accessories on 1.1.1.3", output
    end
  end


  private
    def run_command(*command)
      stdouted { Kamal::Cli::Accessory.start([ *command, "-c", "test/fixtures/deploy_with_accessories.yml" ]) }
    end
end
