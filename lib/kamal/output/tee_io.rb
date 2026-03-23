class Kamal::Output::TeeIO
  def initialize(original, logger)
    @original = original
    @logger = logger
  end

  def <<(message)
    @original << message
    @logger << message

    self
  end
end
