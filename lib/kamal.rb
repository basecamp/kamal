module Kamal
end

require "active_support"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/kamal/sshkit_with_ext.rb")
loader.ignore("#{__dir__}/bin_loader.rb")
loader.setup
loader.eager_load # We need all commands loaded.
