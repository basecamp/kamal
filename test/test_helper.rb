require "bundler/setup"
require "active_support/test_case"
require "active_support/testing/autorun"
require "active_support/testing/stream"
require "debug"
require "mocha/minitest" # using #stubs that can alter returns
require "minitest/autorun" # using #stub that take args
require "sshkit"
require "kamal"

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["VERBOSE"]

# Applies to remote commands only.
SSHKit.config.backend = SSHKit::Backend::Printer

# Ensure local commands use the printer backend too.
# See https://github.com/capistrano/sshkit/blob/master/lib/sshkit/dsl.rb#L9
module SSHKit
  module DSL
    def run_locally(&block)
      SSHKit::Backend::Printer.new(SSHKit::Host.new(:local), &block).run
    end
  end
end

class ActiveSupport::TestCase
  include ActiveSupport::Testing::Stream

  private
    def stdouted
      capture(:stdout) { yield }.strip
    end

    def stderred
      capture(:stderr) { yield }.strip
    end

    def with_test_secrets(**files)
      setup_test_secrets(**files)
      yield
    ensure
      teardown_test_secrets
    end

    def setup_test_secrets(**files)
      @original_pwd = Dir.pwd
      @secrets_tmpdir = Dir.mktmpdir
      fixtures_dup = File.join(@secrets_tmpdir, "test")
      FileUtils.mkdir_p(fixtures_dup)
      FileUtils.cp_r("test/fixtures/", fixtures_dup)

      Dir.chdir(@secrets_tmpdir)
      FileUtils.mkdir_p(".kamal")
      Dir.chdir(".kamal") do
        files.each do |filename, contents|
          File.binwrite(filename.to_s, contents)
        end
      end
    end

    def teardown_test_secrets
      Dir.chdir(@original_pwd)
      FileUtils.rm_rf(@secrets_tmpdir)
    end
end
