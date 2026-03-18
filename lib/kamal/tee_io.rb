class Kamal::TeeIo
  def initialize(original, shipper)
    @original = original
    @shipper = shipper
  end

  def write(str)
    @shipper << str
    @original.write(str)
  end

  def <<(str)
    @shipper << str
    @original << str
    self
  end

  def puts(*args)
    str = args.empty? ? "\n" : args.map(&:to_s).join("\n") + "\n"
    @shipper << str
    @original.puts(*args)
  end

  def print(*args)
    str = args.join
    @shipper << str
    @original.print(*args)
  end

  def flush
    @original.flush if @original.respond_to?(:flush)
  end

  def method_missing(method, *args, &block)
    @original.send(method, *args, &block)
  end

  def respond_to_missing?(method, include_private = false)
    @original.respond_to?(method, include_private)
  end
end
