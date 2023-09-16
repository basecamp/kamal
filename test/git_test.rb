require "test_helper"

class GitTest < ActiveSupport::TestCase
  test "uncommitted changes exist" do
    Kamal::Git.expects(:`).with("git status --porcelain").returns("M   file\n")
    assert_equal "M   file", Kamal::Git.uncommitted_changes
  end

  test "uncommitted changes do not exist" do
    Kamal::Git.expects(:`).with("git status --porcelain").returns("")
    assert_equal "", Kamal::Git.uncommitted_changes
  end
end
