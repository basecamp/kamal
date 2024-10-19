require "test_helper"

class SecretsTest < ActiveSupport::TestCase
  test "fetch" do
    with_test_secrets("secrets" => "SECRET=ABC") do
      assert_equal "ABC", Kamal::Secrets.new["SECRET"]
    end
  end

  test "command interpolation" do
    with_test_secrets("secrets" => "SECRET=$(echo ABC)") do
      assert_equal "ABC", Kamal::Secrets.new["SECRET"]
    end
  end

  test "variable references" do
    with_test_secrets("secrets" => "SECRET1=ABC\nSECRET2=${SECRET1}DEF") do
      assert_equal "ABC", Kamal::Secrets.new["SECRET1"]
      assert_equal "ABCDEF", Kamal::Secrets.new["SECRET2"]
    end
  end

  test "destinations" do
    with_test_secrets("secrets.dest" => "SECRET=DEF", "secrets" => "SECRET=ABC", "secrets-common" => "SECRET=GHI\nSECRET2=JKL") do
      assert_equal "ABC", Kamal::Secrets.new["SECRET"]
      assert_equal "DEF", Kamal::Secrets.new(destination: "dest")["SECRET"]
      assert_equal "GHI", Kamal::Secrets.new(destination: "nodest")["SECRET"]

      assert_equal "JKL", Kamal::Secrets.new["SECRET2"]
      assert_equal "JKL", Kamal::Secrets.new(destination: "dest")["SECRET2"]
      assert_equal "JKL", Kamal::Secrets.new(destination: "nodest")["SECRET2"]
    end
  end

  test "no secrets files" do
    with_test_secrets do
      error = assert_raises(Kamal::ConfigurationError) do
        Kamal::Secrets.new["SECRET"]
      end
      assert_equal "Secret 'SECRET' not found, no secret files (.kamal/secrets-common, .kamal/secrets) provided", error.message

      error = assert_raises(Kamal::ConfigurationError) do
        Kamal::Secrets.new(destination: "dest")["SECRET"]
      end
      assert_equal "Secret 'SECRET' not found, no secret files (.kamal/secrets-common, .kamal/secrets.dest) provided", error.message
    end
  end
end
