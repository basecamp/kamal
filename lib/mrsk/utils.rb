require 'shellwords'

module Mrsk::Utils
  extend self

  DOLLAR_SIGN_WITH_SHELL_EXPANSION_REGEX = /\$\{[^}]+\}/

  # Return a list of escaped shell arguments using the same named argument against the passed attributes (hash or array).
  def argumentize(argument, attributes, sensitive: false)
    Array(attributes).flat_map do |key, value|
      if value.present?
        attr = "#{key}=#{escape_shell_value(value)}"
        attr = self.sensitive(attr, redaction: "#{key}=[REDACTED]") if sensitive
        [ argument, attr]
      else
        [ argument, key ]
      end
    end
  end

  # Return a list of shell arguments using the same named argument against the passed attributes,
  # but redacts and expands secrets.
  def argumentize_env_with_secrets(env)
    if (secrets = env["secret"]).present?
      argumentize("-e", secrets.to_h { |key| [ key, ENV.fetch(key) ] }, sensitive: true) + argumentize("-e", env["clear"])
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

  # Marks sensitive values for redaction in logs and human-visible output.
  # Pass `redaction:` to change the default `"[REDACTED]"` redaction, e.g.
  # `sensitive "#{arg}=#{secret}", redaction: "#{arg}=xxxx"
  def sensitive(...)
    Mrsk::Utils::Sensitive.new(...)
  end

  def redacted(value)
    case
    when value.respond_to?(:redaction)
      value.redaction
    when value.respond_to?(:transform_values)
      value.transform_values { |value| redacted value }
    when value.respond_to?(:map)
      value.map { |element| redacted element }
    else
      value
    end
  end

  def unredacted(value)
    case
    when value.respond_to?(:unredacted)
      value.unredacted
    when value.respond_to?(:transform_values)
      value.transform_values { |value| unredacted value }
    when value.respond_to?(:map)
      value.map { |element| unredacted element }
    else
      value
    end
  end

  # Escape a value to make it safe for shell use.
  def escape_shell_value(value)
    value = value.to_s
    return value.shellescape if value.empty?

    new_value = ''
    while m = value.match(DOLLAR_SIGN_WITH_SHELL_EXPANSION_REGEX)
      new_value << m.pre_match.shellescape unless m.pre_match.empty?
      new_value << m[0]
      value = m.post_match
    end
    new_value << value.shellescape unless value.empty?
    new_value
  end

  # Abbreviate a git revhash for concise display
  def abbreviate_version(version)
    version[0...7] if version
  end
end
