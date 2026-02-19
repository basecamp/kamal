require "test_helper"

class HookOutputTest < ActiveSupport::TestCase
  test "parse returns empty hash when file is empty" do
    hook_output = Kamal::HookOutput.new
    assert_equal({}, hook_output.parse)
  end

  test "parse returns empty hash when nothing is written" do
    hook_output = Kamal::HookOutput.new
    assert File.exist?(hook_output.path)
    assert_equal({}, hook_output.parse)
  end

  test "parse returns key value pairs from dotenv format" do
    hook_output = Kamal::HookOutput.new
    File.write(hook_output.path, "FOO=bar\nBAZ=qux\n")
    assert_equal({ "FOO" => "bar", "BAZ" => "qux" }, hook_output.parse)
  end

  test "parse handles quoted values" do
    hook_output = Kamal::HookOutput.new
    File.write(hook_output.path, "MSG=\"hello world\"\n")
    assert_equal({ "MSG" => "hello world" }, hook_output.parse)
  end

  test "cleanup removes tempfile" do
    hook_output = Kamal::HookOutput.new
    path = hook_output.path
    assert File.exist?(path)
    hook_output.cleanup
    refute File.exist?(path)
  end

  test "parse does not remove tempfile" do
    hook_output = Kamal::HookOutput.new
    path = hook_output.path
    File.write(path, "FOO=bar\n")
    hook_output.parse
    assert File.exist?(path)
    hook_output.cleanup
  end

  test "parse skips comments and blank lines" do
    hook_output = Kamal::HookOutput.new
    File.write(hook_output.path, "# comment\n\nFOO=bar\n")
    assert_equal({ "FOO" => "bar" }, hook_output.parse)
    hook_output.cleanup
  end

  test "parse does not execute command substitution" do
    hook_output = Kamal::HookOutput.new
    File.write(hook_output.path, "VAL=$(echo pwned)\n")
    assert_equal({ "VAL" => "$(echo pwned)" }, hook_output.parse)
    hook_output.cleanup
  end

  test "path is accessible" do
    hook_output = Kamal::HookOutput.new
    assert_kind_of String, hook_output.path
    assert File.exist?(hook_output.path)
    hook_output.cleanup
  end
end
