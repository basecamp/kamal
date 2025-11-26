require "bundler/setup"
require "active_support/test_case"
require "active_support/testing/autorun"
require "active_support/testing/stream"
require "rails/test_unit/line_filtering"
require "pty"
require "debug"
require "mocha/minitest" # using #stubs that can alter returns
require "minitest/autorun" # using #stub that take args
require "sshkit"
require "kamal"

ActiveSupport::LogSubscriber.logger = ActiveSupport::Logger.new(STDOUT) if ENV["VERBOSE"]

# Applies to remote commands only.
SSHKit.config.backend = SSHKit::Backend::Printer

# Disable connection pooling so we don't spawn the eviction thread as
# there's no clean way to kill it after each test
SSHKit::Backend::Netssh.pool = SSHKit::Backend::ConnectionPool.new(0)

class SSHKit::Backend::Printer
  def upload!(local, location, **kwargs)
    local = local.string.inspect if local.respond_to?(:string)
    puts "Uploading #{local} to #{location} on #{host}"
  end
end

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
  extend Rails::LineFiltering

  private
    def stdouted
      capture(:stdout) { yield }.strip
    end

    def stderred
      capture(:stderr) { yield }.strip
    end

    def stub_stdin_tty
      PTY.open do |master, slave|
        stub_stdin(master) { yield }
      end
    end

    def stub_stdin_file
      File.open("/dev/null", "r") do |file|
        stub_stdin(file) { yield }
      end
    end

    def stub_stdin(io)
      original_stdin = STDIN.dup
      STDIN.reopen(io)
      yield
    ensure
      STDIN.reopen(original_stdin)
      original_stdin.close
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
      copy_fixtures(@secrets_tmpdir)

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

    def with_error_pages(directory:)
      error_pages_tmpdir = Dir.mktmpdir

      Dir.mktmpdir do |tmpdir|
        copy_fixtures(tmpdir)

        Dir.chdir(tmpdir) do
          FileUtils.mkdir_p(directory)
          Dir.chdir(directory) do
            File.write("404.html", "404 page")
            File.write("503.html", "503 page")
          end

          yield
        end
      end
    end

    def copy_fixtures(to_dir)
      new_test_dir = File.join(to_dir, "test")
      FileUtils.mkdir_p(new_test_dir)
      FileUtils.cp_r("test/fixtures/", new_test_dir)
    end
end

class SecretAdapterTestCase < ActiveSupport::TestCase
  setup do
    `true` # Ensure $? is 0
  end

  private
    def stub_ticks
      Kamal::Secrets::Adapters::Base.any_instance.stubs(:`)
    end

    def stub_ticks_with(command, succeed: true)
      # Sneakily run `false`/`true` after a match to set $? to 1/0
      stub_ticks.with { |c| c == command && (succeed ? `true` : `false`) }
      Kamal::Secrets::Adapters::Base.any_instance.stubs(:`)
    end

    def shellunescape(string)
      "\"#{string}\"".undump.gsub(/\\([{}])/, "\\1")
    end
end
