module Kamal::Cli
  class BootError < StandardError; end
  class HookError < StandardError; end
  class LockError < StandardError; end
end

# SSHKit uses instance eval, so we need a global const for ergonomics
KAMAL = Kamal::Commander.new
