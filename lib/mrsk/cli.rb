module Mrsk::Cli
end

# SSHKit uses instance eval, so we need a global const for ergonomics
MRSK = Mrsk::Commander.new
