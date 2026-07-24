require "set"

# A console backend for the output framework that replaces the raw SSHKit
# command firehose with a condensed, human-oriented view: a header panel, one
# section per deploy phase, a live status line per host, and a summary panel.
#
# It reconstructs that view purely from the line stream every backend already
# receives (`<<`) plus the modify.kamal start/finish notifications — no deploy
# code needs to know it exists:
#
#   * CLI phase markers (`say "Build and push app image...", :magenta`) arrive
#     host-less with a color set in the +kamal_say_color+ thread-local; each one
#     opens a new phase section.
#   * SSHKit command lines arrive tagged with +kamal_host+ (and +kamal_severity+);
#     the first line from a host in a phase starts its status line, error-level
#     lines mark it failed, and every line is retained for replay on failure.
#   * The modify.kamal exception payload names the hosts/roles that blew up, so
#     failures are attributed even when the stream itself looks clean.
#
# The raw firehose is still teed to any other configured backend (e.g. file),
# so nothing is lost — it's only suppressed on the terminal.
class Kamal::Output::ConsoleLogger < Kamal::Output::BaseLogger
  # Cap the per-host replay buffer so a chatty failure can't pin the whole run
  # of output in memory.
  MAX_RETAINED_LINES = 100

  def self.build(settings:, config:)
    new(config: config, settings: settings || {})
  end

  def initialize(config:, settings: {}, output: $stdout)
    @config = config
    @settings = settings
    @mutex = Mutex.new
    @renderer = build_renderer(output)
    reset_state
    super()
  end

  # Stay out of the way — used when -v/--verbose asks for the raw firehose
  # instead of the condensed view.
  def disable!
    @disabled = true
  end

  def <<(message)
    host = Thread.current[:kamal_host]
    say_color = Thread.current[:kamal_say_color]

    synchronize do
      next unless @active

      if host
        record_host_output(host.to_s, message)
      elsif say_color
        begin_phase(message)
      end
    end
  end

  private
    attr_reader :config, :settings, :renderer

    def on_start(payload)
      synchronize do
        reset_state
        next if @disabled
        @active = true
        renderer.header(
          command: full_command(payload),
          service: config.service,
          version: abbreviated_version,
          destination: config.destination,
          hosts: config.all_hosts.size,
          roles: config.roles.size
        )
      end
    end

    def on_finish(payload, runtime)
      synchronize do
        next unless @active
        note_exception(payload[:exception])
        end_phase
        render_summary(runtime)
        @active = false
      end
    end

    def on_close
      synchronize do
        end_phase if @active
        @active = false
      end
    end

    def reset_state
      @active = false
      @current_phase = nil
      @phase_hosts = {}
      @errored_hosts = Set.new
      @seen_hosts = Set.new
      @retained = Hash.new { |hash, key| hash[key] = [] }
    end

    # --- Event handling (all called while holding the mutex) ---

    def begin_phase(message)
      end_phase
      @current_phase = clean_phase(message)
      @phase_hosts = {}
      renderer.phase(@current_phase)
    end

    def end_phase
      return unless @current_phase

      statuses = @phase_hosts.keys.sort.to_h do |host|
        failed = @errored_hosts.include?(host)
        [ host, { status: failed ? :failed : :ok, duration: clock - @phase_hosts[host] } ]
      end
      renderer.end_phase(statuses)
      @current_phase = nil
    end

    def record_host_output(host, message)
      begin_phase("Running") unless @current_phase
      note_host(host)
      retain(host, message)
    end

    def note_host(host)
      @seen_hosts << host
      unless @phase_hosts.key?(host)
        @phase_hosts[host] = clock
        renderer.host_active(host)
      end
    end

    def mark_failed(host)
      return if @errored_hosts.include?(host)
      @errored_hosts << host
      renderer.host_error(host) if @phase_hosts.key?(host)
    end

    def note_exception(exception)
      return unless exception

      # exception is [ class_name, message ]; our SSHKit patches embed the failing
      # host/role names in the message. Match each candidate host as a whole token
      # so 10.0.0.1 isn't flagged by a failure on 10.0.0.10, and include hosts that
      # failed before emitting any output (so aren't in @seen_hosts yet).
      message = Array(exception).join(" ")
      candidate_hosts.each { |host| mark_failed(host) if message.match?(host_token(host)) }
      @exception = exception
    end

    def candidate_hosts
      (config.all_hosts.map(&:to_s) + @seen_hosts.to_a).uniq
    end

    def host_token(host)
      /(?<![-\w.])#{Regexp.escape(host)}(?![-\w.])/
    end

    def render_summary(runtime)
      renderer.summary(
        ok: (@seen_hosts - @errored_hosts).size,
        failed: @errored_hosts.size,
        needs_attention: @errored_hosts.to_a.sort,
        runtime: runtime,
        exception: @exception
      )

      @errored_hosts.sort.each do |host|
        lines = @retained[host]
        renderer.replay(host, lines) if lines.any?
      end
    end

    # --- Helpers ---

    def retain(host, message)
      buffer = @retained[host]
      buffer.concat(message.to_s.split("\n", -1).reject(&:empty?))
      buffer.shift(buffer.size - MAX_RETAINED_LINES) if buffer.size > MAX_RETAINED_LINES
    end

    def clean_phase(message)
      phase = message.to_s.strip
      phase = phase.chop while phase.end_with?(".", ":")
      phase
    end

    def full_command(payload)
      [ payload[:command], payload[:subcommand] ].compact.join(" ")
    end

    def abbreviated_version
      config.abbreviated_version
    rescue
      nil
    end

    def clock
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def synchronize(&block)
      @mutex.synchronize(&block)
    end

    def build_renderer(output)
      spinner = settings.fetch("spinner", true) && output.respond_to?(:tty?) && output.tty?
      if spinner
        Kamal::Output::Console::TtyRenderer.new(output: output, settings: settings)
      else
        Kamal::Output::Console::PlainRenderer.new(output: output, settings: settings)
      end
    end
end
