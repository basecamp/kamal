module Kamal::Cli
  class LockError < StandardError; end
  class HookError < StandardError; end
end

# SSHKit uses instance eval, so we need a global const for ergonomics
Kamal = Kamal::Commander.new
