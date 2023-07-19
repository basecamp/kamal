require_relative "cli_test_case"

class CliAccessoryTest < CliTestCase
  test "boot" do
    Mrsk::Cli::Accessory.any_instance.expects(:directories).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:upload).with("mysql")

    run_command("boot", "mysql").tap do |output|
      assert_match /docker login.*on 1.1.1.3/, output
      assert_match "docker run --name app-mysql --detach --restart unless-stopped --log-opt max-size=\"10m\" --publish 3306:3306 -e [REDACTED] -e MYSQL_ROOT_HOST=\"%\" --volume $PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf --volume $PWD/app-mysql/data:/var/lib/mysql --label service=\"app-mysql\" mysql:5.7 on 1.1.1.3", output
    end
  end

  test "boot all" do
    Mrsk::Cli::Accessory.any_instance.expects(:directories).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:upload).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:directories).with("redis")
    Mrsk::Cli::Accessory.any_instance.expects(:upload).with("redis")

    run_command("boot", "all").tap do |output|
      assert_match /docker login.*on 1.1.1.3/, output
      assert_match /docker login.*on 1.1.1.1/, output
      assert_match /docker login.*on 1.1.1.2/, output
      assert_match "docker run --name app-mysql --detach --restart unless-stopped --log-opt max-size=\"10m\" --publish 3306:3306 -e [REDACTED] -e MYSQL_ROOT_HOST=\"%\" --volume $PWD/app-mysql/etc/mysql/my.cnf:/etc/mysql/my.cnf --volume $PWD/app-mysql/data:/var/lib/mysql --label service=\"app-mysql\" mysql:5.7 on 1.1.1.3", output
      assert_match "docker run --name app-redis --detach --restart unless-stopped --log-opt max-size=\"10m\" --publish 6379:6379 --volume $PWD/app-redis/data:/data --label service=\"app-redis\" redis:latest on 1.1.1.1", output
      assert_match "docker run --name app-redis --detach --restart unless-stopped --log-opt max-size=\"10m\" --publish 6379:6379 --volume $PWD/app-redis/data:/data --label service=\"app-redis\" redis:latest on 1.1.1.2", output
    end
  end

  test "upload" do
    run_command("upload", "mysql").tap do |output|
      assert_match "mkdir -p app-mysql/etc/mysql", output
      assert_match "test/fixtures/files/my.cnf app-mysql/etc/mysql/my.cnf", output
      assert_match "chmod 755 app-mysql/etc/mysql/my.cnf", output
    end
  end

  test "directories" do
    assert_match "mkdir -p $PWD/app-mysql/data", run_command("directories", "mysql")
  end

  test "reboot" do
    Mrsk::Commands::Registry.any_instance.expects(:login)
    Mrsk::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_container).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:boot).with("mysql", login: false)

    run_command("reboot", "mysql")
  end

  test "start" do
    assert_match "docker container start app-mysql", run_command("start", "mysql")
  end

  test "stop" do
    assert_match "docker container stop app-mysql", run_command("stop", "mysql")
  end

  test "restart" do
    Mrsk::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:start).with("mysql")

    run_command("restart", "mysql")
  end

  test "details" do
    assert_match "docker ps --filter label=service=app-mysql", run_command("details", "mysql")
  end

  test "details with all" do
    run_command("details", "all").tap do |output|
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

  test "logs with follow" do
    SSHKit::Backend::Abstract.any_instance.stubs(:exec)
      .with("ssh -t root@1.1.1.3 'docker logs app-mysql --timestamps --tail 10 --follow 2>&1'")

    assert_match "docker logs app-mysql --timestamps --tail 10 --follow 2>&1", run_command("logs", "mysql", "--follow")
  end

  test "remove with confirmation" do
    Mrsk::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_container).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_image).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_service_directory).with("mysql")

    run_command("remove", "mysql", "-y")
  end

  test "remove all with confirmation" do
    Mrsk::Cli::Accessory.any_instance.expects(:stop).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_container).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_image).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_service_directory).with("mysql")
    Mrsk::Cli::Accessory.any_instance.expects(:stop).with("redis")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_container).with("redis")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_image).with("redis")
    Mrsk::Cli::Accessory.any_instance.expects(:remove_service_directory).with("redis")

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

  private
    def run_command(*command)
      stdouted { Mrsk::Cli::Accessory.start([*command, "-c", "test/fixtures/deploy_with_accessories.yml"]) }
    end
end
