class Kamal::Output::Formatter < SSHKit::Formatter::Pretty
  def initialize(output, logger)
    @logger = logger
    super(output)
  end

  def log_command_start(command)
    with_command_context(command) { super }
  end

  def log_command_data(command, stream_type, stream_data)
    with_command_context(command, iostream: stream_type.to_s) { super }
  end

  def log_command_exit(command)
    with_command_context(command) { super }
  end

  private
    def write_message(verbosity, message, uuid = nil)
      super
      Thread.current[:kamal_severity] = verbosity
      @logger << "#{format_message(verbosity, message, uuid)}\n" rescue nil
    ensure
      Thread.current[:kamal_severity] = nil
    end

    def with_command_context(command, iostream: nil)
      Thread.current[:kamal_host] = command.host.to_s
      Thread.current[:kamal_iostream] = iostream
      yield
    ensure
      Thread.current[:kamal_host] = nil
      Thread.current[:kamal_iostream] = nil
    end
end
