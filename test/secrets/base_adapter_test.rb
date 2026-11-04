require "test_helper"

class SecretsBaseAdapterTest < ActiveSupport::TestCase
  test "capture_command passes env and runs argv without a shell" do
    output = capture_command \
      RbConfig.ruby, "-e", 'print ENV["KAMAL_TEST_SESSION"], " ", ARGV.join(",")', "$HOME;`id`", "a b",
      env: { "KAMAL_TEST_SESSION" => "token" }

    assert_equal "token $HOME;`id`,a b", output
    assert $?.success?
  end

  test "capture_command sets $? like backticks" do
    capture_command RbConfig.ruby, "-e", "exit 3"
    assert_equal 3, $?.exitstatus
  end

  private
    def capture_command(...)
      Kamal::Secrets::Adapters::Test.new.send(:capture_command, ...)
    end
end
