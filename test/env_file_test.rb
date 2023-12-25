require "test_helper"

class EnvFileTest < ActiveSupport::TestCase
  test "env file simple" do
    env = {
      "foo" => "bar",
      "baz" => "haz"
    }

    assert_equal "foo=bar\nbaz=haz\n", \
      Kamal::EnvFile.new(env).to_s
  end

  test "env file clear" do
    env = {
      "clear" => {
        "foo" => "bar",
        "baz" => "haz"
      }
    }

    assert_equal "foo=bar\nbaz=haz\n", \
      Kamal::EnvFile.new(env).to_s
  end

  test "env file empty" do
    assert_equal "\n", Kamal::EnvFile.new({}).to_s
  end

  test "env file secret" do
    ENV["PASSWORD"] = "hello"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\n", \
      Kamal::EnvFile.new(env).to_s
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file secret escaped newline" do
    ENV["PASSWORD"] = "hello\\nthere"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\\\\nthere\n", \
      Kamal::EnvFile.new(env).to_s
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file secret newline" do
    ENV["PASSWORD"] = "hello\nthere"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\\nthere\n", \
      Kamal::EnvFile.new(env).to_s
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file missing secret" do
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_raises(KeyError) { Kamal::EnvFile.new(env).to_s }

  ensure
    ENV.delete "PASSWORD"
  end

  test "env file secret and clear" do
    ENV["PASSWORD"] = "hello"
    env = {
      "secret" => [ "PASSWORD" ],
      "clear" => {
        "foo" => "bar",
        "baz" => "haz"
      }
    }

    assert_equal "PASSWORD=hello\nfoo=bar\nbaz=haz\n", \
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
