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

  test "dotenv load" do
    create_and_remove_secret_files do
      secrets = Kamal::Secrets.new
      assert_equal @value, secrets[@key]
    end
  end

  private

    def create_and_remove_secret_files
      @key = "ABC"
      @value = "SECRET"
      File.write(".env", "#{ @key }=#{ @value }")
      Dir.mkdir(".kamal") if !Dir.exist?(".kamal")
      File.write(".kamal/secrets", "#{ @key }=$#{ @key }")
      yield
      File.delete(".env")
      File.delete(".kamal/secrets")
      Dir.delete(".kamal")
    end
end
