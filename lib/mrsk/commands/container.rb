require "mrsk/commands/base"
require "active_support/duration"
require "active_support/core_ext/numeric/time"

class Mrsk::Commands::Container < Mrsk::Commands::Base
  def list(format: nil, last: -1, filter: nil)
    docker :ps, '--all', format ? "--format=#{format.to_s}" : '', "--filter", "label=service=#{config.service}", last.positive? ? "--last #{last}" : '', filter.present? ? "--filter=#{filter}" : ''
  end

  def rm(ids)
    docker :rm, ids.join(' ')
  end
end
