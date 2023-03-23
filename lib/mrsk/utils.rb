module Mrsk::Utils
  extend self

  # Return a list of escaped shell arguments using the same named argument against the passed attributes (hash or array).
  def argumentize(argument, attributes, redacted: false)
    Array(attributes).flat_map do |key, value|
      if value.present?
        escaped_pair = [ key, escape_shell_value(value) ].join("=")
        [ argument, redacted ? redact(escaped_pair) : escaped_pair ]
      else
        [ argument, key ]
      end
    end
  end

  # Return a list of shell arguments using the same named argument against the passed attributes,
  # but redacts and expands secrets.
  def argumentize_env_with_secrets(env)
    if (secrets = env["secret"]).present?
      argumentize("-e", secrets.to_h { |key| [ key, ENV.fetch(key) ] }, redacted: true) + argumentize("-e", env["clear"])
    else
      argumentize "-e", env.fetch("clear", env)
    end
  end

  # Returns a list of shell-dashed option arguments. If the value is true, it's treated like a value-less option.
  def optionize(args, with: nil)
    options = if with
      flatten_args(args).collect { |(key, value)| value == true ? "--#{key}" : "--#{key}#{with}#{escape_shell_value(value)}" }
    else
      flatten_args(args).collect { |(key, value)| [ "--#{key}", value == true ? nil : escape_shell_value(value) ] }
    end

    options.flatten.compact
  end

  # Flattens a one-to-many structure into an array of two-element arrays each containing a key-value pair
  def flatten_args(args)
    args.flat_map { |key, value| value.try(:map) { |entry| [key, entry] } || [ [ key, value ] ] }
  end

  # Copied from SSHKit::Backend::Abstract#redact to be available inside Commands classes
  def redact(arg) # Used in execute_command to hide redact() args a user passes in
    arg.to_s.extend(SSHKit::Redaction) # to_s due to our inability to extend Integer, etc
  end

  # Escape a value to make it safe for shell use.
  def escape_shell_value(value)
    value.to_s.dump.gsub(/`/, '\\\\`')
  end
end
