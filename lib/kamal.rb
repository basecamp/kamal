module Kamal
  class ConfigurationError < StandardError; end
end

require "active_support"
require "zeitwerk"
require "yaml"
require "tmpdir"
require "pathname"

loader = Zeitwerk::Loader.for_gem
loader.ignore(File.join(__dir__, "kamal", "sshkit_with_ext.rb"))
loader.setup
loader.eager_load_namespace(Kamal::Cli) # We need all commands loaded.
