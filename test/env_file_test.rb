require "test_helper"

class EnvFileTest < ActiveSupport::TestCase
  test "to_s" do
    env = {
      "foo" => "bar",
      "baz" => "haz"
    }

    assert_equal "foo=bar\nbaz=haz\n", \
      Kamal::EnvFile.new(env).to_s
  end

  test "to_s empty" do
    assert_equal "\n", Kamal::EnvFile.new({}).to_s
  end

  test "to_s escaped newline" do
    env = {
      "foo" => "hello\\nthere"
    }

    assert_equal "foo=hello\\\\nthere\n", \
      Kamal::EnvFile.new(env).to_s
  ensure
    ENV.delete "PASSWORD"
  end

  test "to_s newline" do
    env = {
      "foo" => "hello\nthere"
    }

    assert_equal "foo=hello\\nthere\n", \
      Kamal::EnvFile.new(env).to_s
  ensure
    ENV.delete "PASSWORD"
  end

  test "stringIO conversion" do
    env = {
      "foo" => "bar",
      "baz" => "haz"
    }

    assert_equal "foo=bar\nbaz=haz\n", \
      StringIO.new(Kamal::EnvFile.new(env)).read
  end
end
