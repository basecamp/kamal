require "test_helper"

class CliTestCase < ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  setup do
    ENV["VERSION"]             = "999"
    ENV["RAILS_MASTER_KEY"]    = "123"
    ENV["MYSQL_ROOT_PASSWORD"] = "secret123"
    Object.send(:remove_const, :MRSK)
    Object.const_set(:MRSK, Mrsk::Commander.new)
  end

  teardown do
    ENV.delete("RAILS_MASTER_KEY")
    ENV.delete("MYSQL_ROOT_PASSWORD")
    ENV.delete("VERSION")
  end
end
