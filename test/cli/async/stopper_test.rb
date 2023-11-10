require 'test_helper'

class Kamal::Cli::Async::StopperTest < ActiveSupport::TestCase

  setup do
    @version = "999"
    @stop_wait_time = 600
    raw_config = { service: "app", image: "dhh/app", registry: { "username" => "dhh", "password" => "secret" }, servers: [ "1.1.1.1" ], env: { "secret" => [ "RAILS_MASTER_KEY" ] }, stop_wait_time: @stop_wait_time }
    config = Kamal::Configuration.new(raw_config, destination: nil, version: @version)
    @app_commands = Kamal::Commands::App.new(config, role: "web")
  end

  test "stops all containers asynchronously and records the expected maximum stop time" do
    freeze_time do
      with_local_backend do |ssh_context|
        @app_commands.expects(:container_id_for_version).returns('echo "12345678\n87654321"')
        stopper = Kamal::Cli::Async::Stopper.new(@app_commands, version: @version, ssh_context: ssh_context)
        stopper.expects(:execute_stop_command).with(["12345678", "87654321"])
        stopper.stop_async_and_record_stop_time
        assert_equal [ ["12345678", Time.now + @stop_wait_time], ["87654321", Time.now + @stop_wait_time] ], stopper.parse_stop_records
      end.tap do |output|
        assert_match "Stopping 12345678, 87654321 asynchronously...\n", output
      end
    end
  end

  test "only stops containers that are not being stopped already" do
    freeze_time do
      with_local_backend do |ssh_context|
        @app_commands.expects(:container_id_for_version).returns('echo "12345678\n87654321"')
        stopper = Kamal::Cli::Async::Stopper.new(@app_commands, version: @version, ssh_context: ssh_context)
        stopper.write_stop_records([["12345678",Time.now], ["0000001",Time.now]])
        stopper.expects(:execute_stop_command).with(["87654321"])
        stopper.stop_async_and_record_stop_time
        assert_equal [ ["12345678", Time.now], ["0000001", Time.now],["87654321", Time.now + @stop_wait_time] ], stopper.parse_stop_records
      end.tap do |output|
        assert_match "Stopping 87654321 asynchronously...\n", output
      end
    end
  end
  
  test "clears stop records for containers that already_stopped" do
    with_local_backend do |ssh_context|
      stopper = Kamal::Cli::Async::Stopper.new(@app_commands, version: @version, ssh_context: ssh_context)
      stopper.write_stop_records([["12345678",Time.at(0)],["0000001", Time.at(0)]])
      stopper.stubs(:active_containers).returns(["12345678", "87654321"])

      stopper.clean_stop_records
      assert_equal [ ["12345678", Time.at(0)] ], stopper.parse_stop_records
    end
  end

  test "kills zombie containers synchronously if needed" do
    freeze_time do
      ssh_context = mock
      stopper = Kamal::Cli::Async::Stopper.new(@app_commands, version: @version, ssh_context: ssh_context)
      ssh_context.stubs(:execute).with(:touch, ".kamal/app-async_stop_records")
      stopper.stubs(:active_containers).returns(["12345678", "87654321"])
      ssh_context.stubs(:capture_with_info).with(:cat, stopper.async_stop_records)
        .returns("12345678,#{Time.now.utc - 20.minutes}\n0000001,#{Time.now.utc - 20.minutes},87654321,#{Time.now.utc + 20.minutes}")
      
      ssh_context.expects(:warning).with("Container 12345678 failed to be stopped asynchronously. Waiting for it to stop...")
      ssh_context.expects(:execute).with(:docker, :stop, "-t", @stop_wait_time, "12345678")

      stopper.kill_zombie_containers
    end
  end

  test "stops asynchronously, clears the records, and kills zombies" do
    stopper = Kamal::Cli::Async::Stopper.new(@app_commands, version: @version, ssh_context: nil)
    stopper.expects(:stop_async_and_record_stop_time)
    stopper.expects(:clean_stop_records)
    stopper.expects(:kill_zombie_containers)

    stopper.stop
  end

  test "can retrieve active containers" do
    ssh_context = mock
    ssh_context.stubs(:capture_with_info).with(*@app_commands.list_active_containers, "--quiet").returns("12345678\n87654321")
    stopper = Kamal::Cli::Async::Stopper.new(@app_commands, version: @version, ssh_context: ssh_context)
    assert_equal ["12345678", "87654321"], stopper.send(:active_containers)
  end
   
  private

    def with_local_backend
      stdouted do
        SSHKit::Backend::Local.new.tap do |backend|
          Dir.mktmpdir do |tmp_dir|
            backend.within tmp_dir do
              backend.execute :mkdir, "-p", ".kamal"
              yield backend
            end
          end
        end
      end
    end
end