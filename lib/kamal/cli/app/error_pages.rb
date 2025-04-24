class Kamal::Cli::App::ErrorPages
  ERROR_PAGES_GLOB = "{4??.html,5??.html}"

  attr_reader :host, :sshkit
  delegate :upload!, :execute, to: :sshkit

  def initialize(host, sshkit)
    @host = host
    @sshkit = sshkit
  end

  def run
    if KAMAL.config.error_pages_path
      with_error_pages_tmpdir do |local_error_pages_dir|
        execute *KAMAL.app.create_error_pages_directory
        upload! local_error_pages_dir, KAMAL.config.proxy_boot.error_pages_directory, mode: "0700", recursive: true
      end
    end
  end

  private
    def with_error_pages_tmpdir
      Dir.mktmpdir("kamal-error-pages") do |tmpdir|
        error_pages_dir = File.join(tmpdir, KAMAL.config.version)
        FileUtils.mkdir(error_pages_dir)

        if (files = Dir[File.join(KAMAL.config.error_pages_path, ERROR_PAGES_GLOB)]).any?
          FileUtils.cp(files, error_pages_dir)
          yield error_pages_dir
        end
      end
    end
end
