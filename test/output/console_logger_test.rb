require "test_helper"

class OutputConsoleLoggerTest < ActiveSupport::TestCase
  setup do
    @output = StringIO.new
    @logger = build_logger
  end

  teardown { @logger.close }

  test "header panel names the command, service, version and scope" do
    start
    finish

    assert_match "deploy", rendered
    assert_match "myapp@abc1234", rendered
    assert_match "3 hosts, 2 roles", rendered
    assert_match "production", rendered
  end

  test "say markers open phase sections" do
    start
    say "Build and push app image..."
    say "Boot app..."
    finish

    assert_match "❯ Build and push app image", rendered
    assert_match "❯ Boot app", rendered
  end

  test "each active host gets a status line resolved at phase end" do
    start
    say "Boot app..."
    host_line "10.0.0.1", "docker run"
    host_line "10.0.0.2", "docker run"
    finish

    assert_match "✔ 10.0.0.1", rendered
    assert_match "✔ 10.0.0.2", rendered
  end

  test "hosts named in the finish exception are marked failed and listed for attention" do
    start
    say "Boot app..."
    host_line "10.0.0.1", "docker run"
    host_line "10.0.0.2", "docker run"
    finish exception: [ "Kamal::Cli::BootError", "Exception while executing on web: 10.0.0.2 did not boot" ]

    assert_match "✔ 10.0.0.1", rendered
    assert_match "✖ 10.0.0.2", rendered
    assert_match "needs attention: 10.0.0.2", rendered
  end

  test "a host failure isn't misattributed to another whose address is a prefix of it" do
    @logger = build_logger(hosts: %w[ 10.0.0.1 10.0.0.10 ])
    start
    say "Boot app..."
    host_line "10.0.0.1", "docker run"
    host_line "10.0.0.10", "docker run"
    finish exception: [ "Kamal::Cli::BootError", "Exception while executing on web: 10.0.0.10 did not boot" ]

    assert_match "✔ 10.0.0.1", rendered
    assert_match "✖ 10.0.0.10", rendered
    assert_match "needs attention: 10.0.0.10", rendered
    refute_match "needs attention: 10.0.0.1\n", rendered
  end

  test "a host named in the exception that never emitted output is still flagged" do
    start
    say "Connect to servers..."
    finish exception: [ "SSHKit::Runner::ExecuteError", "Exception while executing as deploy@10.0.0.3: connection refused" ]

    assert_match "needs attention: 10.0.0.3", rendered
  end

  test "summary counts successes and failures" do
    start
    say "Boot app..."
    host_line "10.0.0.1", "docker run"
    host_line "10.0.0.2", "docker run"
    finish exception: [ "Kamal::Cli::BootError", "Exception while executing on web: 10.0.0.2 did not boot" ]

    assert_match "✔ 1 ok", rendered
    assert_match "✖ 1 failed", rendered
  end

  test "clean run reports all ok and no failure section" do
    start
    say "Boot app..."
    host_line "10.0.0.1", "docker run"
    finish

    assert_match "✔ 1 ok", rendered
    refute_match "failed", rendered
    refute_match "needs attention", rendered
  end

  test "retained output is replayed only for failed hosts" do
    start
    say "Boot app..."
    host_line "10.0.0.1", "clean output line"
    host_line "10.0.0.2", "failing output line"
    finish exception: [ "Kamal::Cli::BootError", "Exception while executing on web: 10.0.0.2 did not boot" ]

    assert_match "retained output · 10.0.0.2", rendered
    assert_match "failing output line", rendered
    refute_match "clean output line", rendered
  end

  test "verbose disables the condensed view so the raw firehose shows instead" do
    @logger.disable!
    start
    say "Boot app..."
    host_line "10.0.0.1", "docker run"
    finish

    assert_empty rendered
  end

  test "only magenta say markers open phase sections" do
    start
    say "Build and push app image...", color: :magenta
    say "Skipping something", color: :yellow
    finish

    assert_match "❯ Build and push app image", rendered
    refute_match "❯ Skipping something", rendered
  end

  test "non-phase say output is surfaced as a notice, not dropped" do
    start
    say "Boot app...", color: :magenta
    say "Aborted", color: :red
    finish

    assert_match "Aborted", rendered
  end

  test "host output before any marker opens an implicit phase" do
    start
    host_line "10.0.0.1", "docker run"
    finish

    assert_match "❯ Running", rendered
    assert_match "✔ 10.0.0.1", rendered
  end

  test "ignores the line stream before start and after finish" do
    host_line "10.0.0.1", "before start"
    start
    finish
    say "After finish..."

    refute_match "before start", rendered
    refute_match "After finish", rendered
  end

  private
    def build_logger(hosts: %w[ 10.0.0.1 10.0.0.2 10.0.0.3 ])
      Kamal::Output::ConsoleLogger.new(config: config_double(hosts), settings: { "color" => false }, output: @output)
    end

    def config_double(hosts)
      Class.new do
        def initialize(hosts); @hosts = hosts; end
        def service; "myapp"; end
        def destination; "production"; end
        attr_reader :hosts
        alias_method :all_hosts, :hosts
        def roles; %i[ web worker ]; end
        def abbreviated_version; "abc1234"; end
      end.new(hosts)
    end

    def start(command: "deploy", **payload)
      @logger.start("modify.kamal", "id", command: command, destination: "production", **payload)
    end

    def finish(exception: nil)
      @logger.finish("modify.kamal", "id", exception: exception)
    end

    def say(message, color: :magenta)
      with_context(say: true, say_color: color) { @logger << "#{message}\n" }
    end

    def host_line(host, message)
      with_context(host: host) { @logger << "#{message}\n" }
    end

    def with_context(host: nil, say: nil, say_color: nil)
      Thread.current[:kamal_host] = host
      Thread.current[:kamal_say] = say
      Thread.current[:kamal_say_color] = say_color
      yield
    ensure
      Thread.current[:kamal_host] = Thread.current[:kamal_say] = Thread.current[:kamal_say_color] = nil
    end

    def rendered
      @output.string
    end
end
