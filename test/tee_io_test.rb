require "test_helper"

class TeeIoTest < ActiveSupport::TestCase
  setup do
    @original = StringIO.new
    @shipper = StringIO.new
    @tee = Kamal::TeeIo.new(@original, @shipper)
  end

  test "write sends to both original and shipper" do
    @tee.write("hello")

    assert_equal "hello", @original.string
    assert_equal "hello", @shipper.string
  end

  test "puts writes line with newline" do
    @tee.puts("hello")

    assert_equal "hello\n", @original.string
  end

  test "puts with no args writes newline" do
    @tee.puts

    assert_equal "\n", @original.string
  end

  test "puts with multiple args joins with newlines" do
    @tee.puts("one", "two")

    assert_equal "one\ntwo\n", @original.string
  end

  test "print writes without newline" do
    @tee.print("hello", " world")

    assert_equal "hello world", @original.string
  end

  test "shovel operator writes and returns self" do
    result = @tee << "hello"

    assert_equal "hello", @original.string
    assert_same @tee, result
  end

  test "flush delegates to original" do
    @original.expects(:flush)
    @tee.flush
  end

  test "delegates unknown methods to original" do
    assert_equal @original.string.length, @tee.size
  end

  test "responds to original methods" do
    assert @tee.respond_to?(:string)
  end
end
