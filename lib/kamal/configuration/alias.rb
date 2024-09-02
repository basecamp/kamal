class Kamal::Configuration::Alias
  include Kamal::Configuration::Validation

  attr_reader :name, :command

  def initialize(name, config:)
    @name, @command = name.inquiry, config.raw_config["aliases"][name]

    validate! \
      command,
      example: validation_yml["aliases"]["uname"],
      context: "aliases/#{name}",
      with: Kamal::Configuration::Validator::Alias
  end
end
