class Kamal::Secrets::Dotenv::InlineCommandSubstitution
  class << self
    def install!
      ::Dotenv::Parser.substitutions.map! { |sub| sub == ::Dotenv::Substitutions::Command ? self : sub }
    end

    # Improved version of Dotenv::Substitutions::Command's INTERPOLATED_SHELL_COMMAND
    # Handles:
    #   $(echo 'foo)')
    #   $(echo "foo)")
    #   $(echo foo\))
    #   $(echo "foo\")")
    #   $(echo foo\\)
    #   $(echo 'foo'"'"')')
    INTERPOLATED_SHELL_COMMAND = /
      (?<backslash>\\)?         # (1) Optional backslash (escaped '$')
      \$                        # (2) Match a literal '$' (start of command)
      (?<cmd>                   # (3) Capture the command within '$()' as 'cmd'
        \(                      # (4) Require an opening parenthesis '('
        (?:                     # (5) Match either:
          [^()\\'"]+            #     - Any non-parens, non-escape, non-quotes (normal chars)
          | \\ (?!\)) .         #     - Escaped character (e.g., `\(`, `\'`, `\"`), but **not** `\)` alone
          | \\\\ \)             #     - Special case: Match `\\)` as a literal `\)`
          | '(?:[^'\\]* (?:\\.[^'\\]*)*)'  # - Single-quoted strings with escaped quotes (`\'`)
          | "(?:[^"\\]* (?:\\.[^"\\]*)*)"  # - Double-quoted strings with escaped quotes (`\"`)
          | '(?:[^']*)' (?:"[^"]*")*       # - Single-quoted, followed by optional mixed double-quoted parts
          | "(?:[^"]*)" (?:'[^']*')*       # - Double-quoted, followed by optional mixed single-quoted parts
          | \g<cmd>             #     - Nested `$()` expressions (recursive call)
        )*                      # (6) Repeat to allow full parsing
        \)                      # (7) Require a closing parenthesis ')'
      )
    /x

    def call(value, _env, overwrite: false)
      # Process interpolated shell commands
      value.gsub(INTERPOLATED_SHELL_COMMAND) do |*|
        # Eliminate opening and closing parentheses
        command = $LAST_MATCH_INFO[:cmd][1..-2]

        if $LAST_MATCH_INFO[:backslash]
          # Command is escaped, don't replace it.
          $LAST_MATCH_INFO[0][1..]
        else
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
