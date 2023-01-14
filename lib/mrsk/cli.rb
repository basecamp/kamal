require "mrsk"

MRSK = Mrsk::Commander.new \
  config_file: Pathname.new(File.expand_path("config/deploy.yml"))

module Mrsk::Cli
end

require "mrsk/cli/main"
