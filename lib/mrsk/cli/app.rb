require "mrsk/cli/base"

class Mrsk::Cli::App < Mrsk::Cli::Base
  desc "boot", "Boot app on servers (or start them if they've already been booted)"
  def boot
    MRSK.config.roles.each do |role|
      on(role.hosts) do |host|
        begin
          execute *MRSK.app.run(role: role.name)
        rescue SSHKit::Command::Failed => e
          if e.message =~ /already in use/
            error "Container with same version already deployed on #{host}, starting that instead"
            execute *MRSK.app.start, host: host
          else
            raise
          end
        end
      end
    end
  end
  
  desc "start", "Start existing app on servers (use --version=<git-hash> to designate specific version)"
  option :version, desc: "Defaults to the most recent git-hash in local repository"
  def start
    if (version = options[:version]).present?
      on(MRSK.config.hosts) { execute *MRSK.app.start(version: version) }
    else
      on(MRSK.config.hosts) { execute *MRSK.app.start, raise_on_non_zero_exit: false }
    end
  end
  
  desc "stop", "Stop app on servers"
  def stop
    on(MRSK.config.hosts) { execute *MRSK.app.stop, raise_on_non_zero_exit: false }
  end
  
  desc "details", "Display details about app containers"
  def details
    on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.info, verbosity: Logger::INFO) + "\n\n" }
  end
  
  desc "exec [CMD]", "Execute a custom task on servers passed in as CMD='bin/rake some:task'"
  option :once, type: :boolean, default: false, desc: "Only perform command on primary host"
  option :run, type: :boolean, default: false, desc: "Start a new container to run the command rather than reusing existing"
  def exec(cmd)
    runner = options[:run] ? :run_exec : :exec

    if options[:once]
      on(MRSK.config.primary_host) { puts capture(*MRSK.app.send(runner, cmd), verbosity: Logger::INFO) }
    else
      on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.send(runner, cmd), verbosity: Logger::INFO) + "\n\n" }
    end
  end

  desc "console", "Start Rails Console on primary host"
  option :host, desc: "Start console on a different host"
  def console
    host = options[:host] || MRSK.config.primary_host

    run_locally do
      puts "Launching Rails console on #{host}..."
      exec MRSK.app.console(host: host)        
    end
  end

  desc "runner [EXPRESSION]", "Execute Rails runner with given expression"
  option :once, type: :boolean, default: false, desc: "Only perform runner on primary host"
  def runner(expression)
    if options[:once]
      on(MRSK.config.primary_host) { puts capture(*MRSK.app.exec("bin/rails", "runner", "'#{expression}'"), verbosity: Logger::INFO) }
    else
      on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.exec("bin/rails", "runner", "'#{expression}'"), verbosity: Logger::INFO) + "\n\n" }
    end
  end

  desc "containers", "List all the app containers currently on servers"
  def containers
    on(MRSK.config.hosts) { |host| puts "App Host: #{host}\n" + capture(*MRSK.app.list_containers, verbosity: Logger::INFO) + "\n\n" }
  end
  
  desc "logs", "Show last 100 log lines from app on servers"
  option :lines, type: :numeric, aliases: "-n", default: 1000, desc: "Number of log lines to pull from each server"
  option :grep, aliases: "-g", desc: "Show lines with grep match only (use this to fetch specific requests by id)"
  def logs
    # FIXME: Catch when app containers aren't running
    lines = options[:lines]
    grep  = options[:grep]
    on(MRSK.config.hosts) do |host|
      begin
        puts "App Host: #{host}\n" + capture(*MRSK.app.logs(lines: lines, grep: grep), verbosity: Logger::INFO) + "\n\n"
      rescue SSHKit::Command::Failed
        puts "App Host: #{host}\nNothing found\n\n"
      end
    end
  end
  
  desc "remove", "Remove app containers and images from servers"
  option :only, default: "", desc: "Use 'containers' or 'images'"
  def remove
    case options[:only]
    when "containers"
      on(MRSK.config.hosts) { execute *MRSK.app.remove_containers }
    when "images"
      on(MRSK.config.hosts) { execute *MRSK.app.remove_images }
    else
      on(MRSK.config.hosts) { execute *MRSK.app.remove_containers }
      on(MRSK.config.hosts) { execute *MRSK.app.remove_images }
    end
  end
end
