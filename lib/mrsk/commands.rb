module Mrsk::Commands
  class Base
    attr_accessor :config

    def initialize(config)
      @config = config
    end
  end
end

require "mrsk/commands/app"
require "mrsk/commands/traefik"
require "mrsk/commands/registry"
