module Mrsk
end

require "active_support"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/mrsk/sshkit_with_ext.rb")
loader.setup
loader.eager_load # We need all commands loaded.
