require "test_helper"

class GitTest < ActiveSupport::TestCase
  test "user name reads UTF-8 bytes under US-ASCII external encoding" do
    user_name = +"Сергей Федоров\n"
    user_name.force_encoding(Encoding::US_ASCII)

    Kamal::Git.expects(:`).with("git config user.name").returns(user_name)

    result = Kamal::Git.user_name

    assert_equal "Сергей Федоров", result
    assert_predicate result, :valid_encoding?
  end

  test "uncommitted changes exist" do
    Kamal::Git.expects(:`).with("git status --porcelain").returns("M   file\n")
    assert_equal "M   file", Kamal::Git.uncommitted_changes
  end

  test "uncommitted changes do not exist" do
    Kamal::Git.expects(:`).with("git status --porcelain").returns("")
    assert_equal "", Kamal::Git.uncommitted_changes
  end
end
