module Mrsk::Utils
  extend self

  # Copied from SSHKit::Backend::Abstract#redact to be available inside Commands classes
  def redact(arg) # Used in execute_command to hide redact() args a user passes in
    arg.to_s.extend(SSHKit::Redaction) # to_s due to our inability to extend Integer, etc
  end
end
