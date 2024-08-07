module Kamal::Secrets::Adapters
  def self.lookup(name)
    case name
    when "1password"
      Kamal::Secrets::Adapters::OnePassword.new
    else
      Object.const_get("Kamal::Secrets::Adapters::#{name.camelize}").new
    end
  rescue NameError
    raise RuntimeError, "Unknown secrets adapter: #{name}"
  end
end
