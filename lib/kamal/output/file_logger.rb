class Kamal::Output::FileLogger < Kamal::Output::BaseLogger
  attr_reader :path

  def self.build(settings:, config:)
    raise ArgumentError, "file path is required" unless settings["path"]
    new(path: settings["path"])
  end

  def initialize(path:)
    @path = Pathname.new(path)
    super()
  end

  def <<(message)
    @file&.print(message)
  end

  private
    def on_start(payload)
      path.mkpath
      @file_path = path.join(filename_for(payload))
      @file = File.open(@file_path, "a")
      @file.sync = true
    end

    def on_finish(payload, runtime)
      if @file
        if payload[:exception]
          error_class, error_message = payload[:exception]
          @file.puts "# FAILED: #{error_class}: #{error_message} (#{runtime}s)"
        else
          @file.puts "# Completed in #{runtime}s"
        end
        @file.close
        @file = nil
        puts "Logs written to #{@file_path}"
      end
    end

    def on_close
      if @file
        @file.close
        @file = nil
      end
    end

    def filename_for(payload)
      command = [ payload[:command], payload[:subcommand] ].compact.join("_")
      [ Time.now.strftime("%Y-%m-%dT%H-%M-%S"), payload[:destination], command ].compact.join("_") + ".log"
    end
end
