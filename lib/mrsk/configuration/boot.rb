class Mrsk::Configuration::Boot
  attr_reader :group_wait, :group_limit

  def initialize(section:)
    section = section || {}
    @group_limit = section["group_limit"]
    @group_wait = section["group_wait"]
  end
end
