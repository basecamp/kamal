module Mrsk::Utils
  extend self

  # Return a list of shell arguments using the same named argument against the passed attributes.
  def argumentize(argument, attributes, redacted: false)
    attributes.flat_map { |k, v| [ argument, redacted ? redact("#{k}=#{v}") : "#{k}=#{v}" ] }
  end

  # Copied from SSHKit::Backend::Abstract#redact to be available inside Commands classes
  def redact(arg) # Used in execute_command to hide redact() args a user passes in
    arg.to_s.extend(SSHKit::Redaction) # to_s due to our inability to extend Integer, etc
  end
end
