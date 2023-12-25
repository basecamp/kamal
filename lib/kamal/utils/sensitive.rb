require "active_support/core_ext/module/delegation"
require "sshkit"

class Kamal::Utils::Sensitive
  # So SSHKit knows to redact these values.
  include SSHKit::Redaction

  attr_reader :unredacted, :redaction
  delegate :to_s, to: :unredacted
  delegate :inspect, to: :redaction

  def initialize(value, redaction: "[REDACTED]")
    @unredacted, @redaction = value, redaction
  end

  # Sensitive values won't leak into YAML output.
  def encode_with(coder)
    coder.represent_scalar nil, redaction
  end
end
