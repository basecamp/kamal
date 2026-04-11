require "test_helper"
require "tmpdir"

class OutputFileLoggerTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir
    @logger = Kamal::Output::FileLogger.new(path: @dir)
  end

  teardown do
    @logger.close
    FileUtils.rm_rf(@dir)
  end

  test "discards lines before start" do
    @logger << "before modify\n"

    assert_empty log_files
  end

  test "creates timestamped log file on start" do
    @logger.start("modify.kamal", "id", command: "deploy")

    assert_equal 1, log_files.length
    assert_match /_deploy\.log$/, log_files.first
  end

  test "writes lines to file after start" do
    @logger.start("modify.kamal", "id", command: "deploy")
    @logger << "hello\n"
    @logger << "world\n"

    assert_includes log_content, "hello"
    assert_includes log_content, "world"
  end

  test "finish writes completion message" do
    @logger.start("modify.kamal", "id", command: "deploy")
    @logger.finish("modify.kamal", "id", {})

    assert_match /# Completed in \d+\.\d+s/, log_content
  end

  test "finish writes failure message on exception" do
    @logger.start("modify.kamal", "id", command: "deploy")
    @logger.finish("modify.kamal", "id", exception: [ "RuntimeError", "boom" ])

    assert_includes log_content, "# FAILED: RuntimeError: boom"
  end

  test "includes subcommand in filename" do
    @logger.start("modify.kamal", "id", command: "app", subcommand: "boot")

    assert_match /_app_boot\.log$/, log_files.first
  end

  test "includes destination in filename" do
    @logger.start("modify.kamal", "id", command: "deploy", destination: "staging")

    assert_match /_staging_deploy\.log$/, log_files.first
  end

  test "includes destination and subcommand in filename" do
    @logger.start("modify.kamal", "id", command: "app", subcommand: "boot", destination: "staging")

    assert_match /_staging_app_boot\.log$/, log_files.first
  end

  test "finish prints log file path" do
    @logger.start("modify.kamal", "id", command: "deploy")

    output = capture_io { @logger.finish("modify.kamal", "id", {}) }.first
    assert_match /Logs written to.*_deploy\.log/, output
  end

  test "close is idempotent" do
    @logger.start("modify.kamal", "id", command: "deploy")
    @logger.close
    assert_nothing_raised { @logger.close }
  end

  private
    def log_files
      Dir.glob("#{@dir}/*.log")
    end

    def log_content
      File.read(log_files.first)
    end
end
