require "test_helper"

class EnvFilesTest < ActiveSupport::TestCase
  test "env file simple" do
    env = {
      "foo" => "bar",
      "baz" => "haz"
    }

    assert_equal "foo=bar\nbaz=haz\n", Kamal::EnvFiles.new(env).clear
    assert_equal "\n", Kamal::EnvFiles.new(env).secret
  end

  test "env file clear" do
    env = {
      "clear" => {
        "foo" => "bar",
        "baz" => "haz"
      }
    }

    assert_equal "foo=bar\nbaz=haz\n", Kamal::EnvFiles.new(env).clear
    assert_equal "\n", Kamal::EnvFiles.new(env).secret
  end

  test "env file empty" do
    assert_equal "\n", Kamal::EnvFiles.new({}).secret
    assert_equal "\n", Kamal::EnvFiles.new({}).clear
  end

  test "env file secret" do
    ENV["PASSWORD"] = "hello"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\n", Kamal::EnvFiles.new(env).secret
    assert_equal "\n", Kamal::EnvFiles.new(env).clear
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file secret escaped newline" do
    ENV["PASSWORD"] = "hello\\nthere"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\\\\nthere\n", Kamal::EnvFiles.new(env).secret
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file secret newline" do
    ENV["PASSWORD"] = "hello\nthere"
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_equal "PASSWORD=hello\\nthere\n", Kamal::EnvFiles.new(env).secret
  ensure
    ENV.delete "PASSWORD"
  end

  test "env file missing secret" do
    env = {
      "secret" => [ "PASSWORD" ]
    }

    assert_raises(KeyError) { Kamal::EnvFiles.new(env).secret }

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

    assert_equal "PASSWORD=hello\n", Kamal::EnvFiles.new(env).secret
    assert_equal "foo=bar\nbaz=haz\n", Kamal::EnvFiles.new(env).clear

  ensure
    ENV.delete "PASSWORD"
  end

  test "stringIO conversion" do
    env = {
      "foo" => "bar",
      "baz" => "haz"
    }

    assert_equal "foo=bar\nbaz=haz\n", \
      StringIO.new(Kamal::EnvFiles.new(env).clear).read
  end
end
