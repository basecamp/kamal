class Kamal::Secrets::Dotenv::InlineCommandSubstitution
  class << self
    def install!
      ::Dotenv::Parser.substitutions.map! { |sub| sub == ::Dotenv::Substitutions::Command ? self : sub }
    end

    def call(value, _env, overwrite: false)
      # Process interpolated shell commands
      value.gsub(Dotenv::Substitutions::Command.singleton_class::INTERPOLATED_SHELL_COMMAND) do |*|
        # Eliminate opening and closing parentheses
        command = $LAST_MATCH_INFO[:cmd][1..-2]

        if $LAST_MATCH_INFO[:backslash]
          # Command is escaped, don't replace it.
          $LAST_MATCH_INFO[0][1..]
        else
          if command =~ /\A\s*kamal\s*secrets\s+/
            # Inline the command
            capture_stdout { Kamal::Cli::Main.start(command.shellsplit[1..]) }.chomp
          else
            # Execute the command and return the value
            `#{command}`.chomp
          end
        end
      end
    end

    def capture_stdout
      old_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end
end
