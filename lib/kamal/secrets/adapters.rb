require "active_support/core_ext/string/inflections"
module Kamal::Secrets::Adapters
  def self.lookup(name)
    name = "one_password" if name.downcase == "1password"
    name = "last_pass" if name.downcase == "lastpass"
    name = "gcp_secret_manager" if name.downcase == "gcp"
    name = "bitwarden_secrets_manager" if name.downcase == "bitwarden-sm"
    adapter_class(name)
  end

  def self.adapter_class(name)
    Object.const_get("Kamal::Secrets::Adapters::#{name.camelize}").new
  rescue NameError => e
    raise RuntimeError, "Unknown secrets adapter: #{name}"
  end
end
