class Kamal::TeeIo
  def initialize(original, shipper)
    @original = original
    @shipper = shipper
  end

  def write(str)
    @shipper << str
    @original.write(str)
  end

  def puts(*args)
    write(args.empty? ? "\n" : args.map(&:to_s).join("\n") + "\n")
  end

  def print(*args)
    write(args.join)
  end

  def <<(str)
    write(str.to_s)
    self
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
