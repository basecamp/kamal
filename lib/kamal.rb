module Kamal
  class ConfigurationError < StandardError; end
end

require "active_support"
require "zeitwerk"
require "yaml"

loader = Zeitwerk::Loader.for_gem
loader.ignore(File.join(__dir__, "kamal", "sshkit_with_ext.rb"))
loader.setup
loader.eager_load # We need all commands loaded.
