class Kamal::Secrets::Dotenv::InlineCommandSubstitution
  # Unlike dotenv, this regex does not match escaped
  # parentheses when looking for command substitutions.
  INTERPOLATED_SHELL_COMMAND = /
    (?<backslash>\\)?          # is it escaped with a backslash?
    \$                         # literal $
    (?<cmd>                    # collect command content for eval
      \(                       # require opening paren
      (?:\\.|[^()\\]|\g<cmd>)+ # allow any number of non-parens or escaped
                               # parens (by nesting the <cmd> expression
                               # recursively)
      \)                       # require closing paren
    )
  /x

  class << self
    def install!
      ::Dotenv::Parser.substitutions.map! { |sub| sub == ::Dotenv::Substitutions::Command ? self : sub }
    end

    def call(value, env, overwrite: false)
      # Process interpolated shell commands
      value.gsub(INTERPOLATED_SHELL_COMMAND) do |*|
        # Eliminate opening and closing parentheses
        command = $LAST_MATCH_INFO[:cmd][1..-2]

        if $LAST_MATCH_INFO[:backslash]
          # Command is escaped, don't replace it.
          $LAST_MATCH_INFO[0][1..]
        else
          command = ::Dotenv::Substitutions::Variable.call(command, env)
          if command =~ /\A\s*kamal\s*secrets\s+/
            # Inline the command
            inline_secrets_command(command)
          else
            # Execute the command and return the value
            `#{command}`.chomp
          end
        end
      end
    end

    def inline_secrets_command(command)
      Kamal::Cli::Main.start(command.shellsplit[1..] + [ "--inline" ]).chomp
    end
  end
end
