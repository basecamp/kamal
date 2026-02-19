require "tempfile"

class Kamal::HookOutput
  attr_reader :path

  def initialize
    @tempfile = Tempfile.new("kamal_hook_output")
    @path = @tempfile.path
  end

  # Parse KEY=VALUE lines without command substitution.
  # Dotenv.parse is unsafe here — it executes $(...) in values.
  def parse
    return {} unless File.exist?(path) && File.size(path) > 0

    File.readlines(path, chomp: true).each_with_object({}) do |line, hash|
      next if line.empty? || line.start_with?("#")
      if (match = line.match(/\A([^=]+)=(.*)\z/))
        key = match[1]
        value = match[2]
        value = value[1..-2] if value =~ /\A(["'])(.*)\1\z/
        hash[key] = value
      end
    end
  end

  def cleanup
    @tempfile.close!
  end
end
