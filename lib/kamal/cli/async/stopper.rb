require "kamal/sshkit_with_ext"

class Kamal::Cli::Async::Stopper
    attr_accessor :app_commands, :version
    def initialize(app_commands, version:, ssh_context:)
        @app_commands = app_commands
        @version = version
        @ssh_context = ssh_context
    end

    def stop
      stop_async_and_record_stop_time
      kill_zombie_containers
      clean_stop_records
    end
  
    def stop_async_and_record_stop_time
      container_ids = capture_with_info(*app_commands.container_id_for_version(version)).split("\n")
      container_ids = container_ids.reject{|id| parse_stop_records.map(&:first).include?(id)}
      unless container_ids.empty?
        info "Stopping #{container_ids.join(', ')} asynchronously..."
        execute_stop_command(container_ids)
        record_stop_time(container_ids, async_stop_records)
      end
    end

    def record_stop_time(container_ids, async_stop_records)
      stop_time = (Time.now.utc + (app_commands.config.stop_wait_time || 0)).iso8601
      to_append = container_ids.map do |container_id|
        "#{container_id},#{stop_time}"
      end

      execute :echo , "\"#{to_append.join("\n")}\"", ">>", async_stop_records
    end


    def kill_zombie_containers
      active_containers = self.active_containers
      zombie_containers = parse_stop_records.filter do |container_id, stop_time|
        active_containers.include?(container_id) && stop_time < Time.now.utc
      end

      for container_id, stop_time in zombie_containers
        warning "Container #{container_id} failed to be stopped asynchronously. Waiting for it to stop..."
        execute *app_commands.stop_container(container_id)
      end
    end

    def clean_stop_records
      active_containers = self.active_containers
      relevant_records = parse_stop_records.filter do |container_id, stop_time|
        active_containers.include?(container_id)
      end

      write_stop_records(relevant_records)
    end

    def write_stop_records(records)
      file_content = records.map do |container_id, stop_time|
        "#{container_id},#{stop_time}"
      end.join("\n")
      execute :echo, "\"#{file_content}\"", ">", async_stop_records
    end

    def parse_stop_records
      touch_stop_records_file
      text = capture_with_info(*[:cat, async_stop_records])
      text.split("\n").map do |line|
        container_id, stop_time = line.split(',')
        [container_id, Time.parse(stop_time)]
      end
    end
    
    def async_stop_records
      "#{app_commands.config.run_directory}/#{[app_commands.config.service, app_commands.config.destination, 'async_stop_records'].compact.join('-')}"
    end

    private

      def active_containers
        capture_with_info(*@app_commands.list_active_containers, "--quiet").split("\n")
      end

      def execute_stop_command(container_ids)
        execute *app_commands.stop_containers_async(container_ids)
      end
    
      def touch_stop_records_file
        execute :touch, async_stop_records
      end


      def execute(*arguments)
        @ssh_context.execute(*arguments)
      end

      def capture_with_info(*arguments)
        @ssh_context.capture_with_info(*arguments)
      end

      def info(*arguments)
        @ssh_context.info(*arguments)
      end

      def warning(*arguments)
        @ssh_context.warning(*arguments)
      end
end