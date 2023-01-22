module Mrsk::Utils
  extend self

  # Return a list of shell arguments using the same named argument against the passed attributes (hash or array).
  def argumentize(argument, attributes, redacted: false)
    Array(attributes).flat_map do |k, v|
      if v.present?
        [ argument, redacted ? redact("#{k}=#{v}") : "#{k}=#{v}" ]
      else
        [ argument, k ]
      end
    end
  end

  # Return a list of shell arguments using the same named argument against the passed attributes,
  # but redacts and expands secrets.
  def argumentize_env_with_secrets(env)
    if (secrets = env["secret"]).present?
      argumentize("-e", secrets.to_h { |key| [ key, ENV.fetch(key) ] }, redacted: true) + argumentize("-e", env["clear"])
    else
      argumentize "-e", env
    end
  end

  # Copied from SSHKit::Backend::Abstract#redact to be available inside Commands classes
  def redact(arg) # Used in execute_command to hide redact() args a user passes in
    arg.to_s.extend(SSHKit::Redaction) # to_s due to our inability to extend Integer, etc
  end
end
