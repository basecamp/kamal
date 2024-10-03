require "active_support/core_ext/object/try"

module Kamal::Utils
  extend self

  DOLLAR_SIGN_WITHOUT_SHELL_EXPANSION_REGEX = /\$(?!{[^\}]*\})/

  # Return a list of escaped shell arguments using the same named argument against the passed attributes (hash or array).
  def argumentize(argument, attributes, sensitive: false)
    Array(attributes).flat_map do |key, value|
      if value.present?
        attr = "#{key}=#{escape_shell_value(value)}"
        attr = self.sensitive(attr, redaction: "#{key}=[REDACTED]") if sensitive
        [ argument, attr ]
      elsif value == false
        [ argument, "#{key}=false" ]
      else
        [ argument, key ]
      end
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
    args.flat_map { |key, value| value.try(:map) { |entry| [ key, entry ] } || [ [ key, value ] ] }
  end

  # Marks sensitive values for redaction in logs and human-visible output.
  # Pass `redaction:` to change the default `"[REDACTED]"` redaction, e.g.
  # `sensitive "#{arg}=#{secret}", redaction: "#{arg}=xxxx"
  def sensitive(...)
    Kamal::Utils::Sensitive.new(...)
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

  # Escape a value to make it safe for shell use.
  def escape_shell_value(value)
    value.to_s.scan(/[\x00-\x7F]+|[^\x00-\x7F]+/) \
      .map { |part| part.ascii_only? ? escape_ascii_shell_value(part) : part }
      .join
  end

  def escape_ascii_shell_value(value)
    value.to_s.dump
      .gsub(/`/, '\\\\`')
      .gsub(DOLLAR_SIGN_WITHOUT_SHELL_EXPANSION_REGEX, '\$')
  end

  # Apply a list of host or role filters, including wildcard matches
  def filter_specific_items(filters, items)
    matches = []

    Array(filters).select do |filter|
      matches += Array(items).select do |item|
        # Only allow * for a wildcard
        # items are roles or hosts
        File.fnmatch(filter, item.to_s, File::FNM_EXTGLOB)
      end
    end

    matches.uniq
  end

  def stable_sort!(elements, &block)
    elements.sort_by!.with_index { |element, index| [ block.call(element), index ] }
  end

  def join_commands(commands)
    commands.map(&:strip).join(" ")
  end

  def docker_arch
    arch = `docker info --format '{{.Architecture}}'`.strip
    case arch
    when /aarch64/
      "arm64"
    when /x86_64/
      "amd64"
    else
      arch
    end
  end

  def older_version?(version, other_version)
    Gem::Version.new(version.delete_prefix("v")) < Gem::Version.new(other_version.delete_prefix("v"))
  end
end
