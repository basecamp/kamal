require "pastel"

# Shared formatting for the console renderers: colors, icons, and the rounded
# panels used for the header and summary. Subclasses implement the event
# methods (+header+, +phase+, +host_active+, +end_phase+, +summary+, +replay+)
# that the ConsoleLogger drives.
class Kamal::Output::Console::Renderer
  OK = "✔"
  FAIL = "✖"
  ARROW = "❯"
  BAR = "┃"

  def initialize(output:, settings: {})
    @output = output
    @settings = settings
    @pastel = Pastel.new(enabled: color_enabled?)
  end

  def header(command:, service:, version:, destination:, hosts:, roles:); end
  def phase(name); end
  def host_active(host); end
  def end_phase(statuses); end
  def notice(message, color); end
  def summary(ok:, failed:, needs_attention:, runtime:, exception:); end
  def replay(host, lines); end
  def host_error(host); end

  private
    attr_reader :output, :settings, :pastel

    def color_enabled?
      return settings["color"] if settings.key?("color")
      output.respond_to?(:tty?) && output.tty?
    end

    def puts(line = "")
      output.puts(line)
    end

    # A rounded panel with a highlighted title, sized to its widest line.
    def panel(title, lines, color: :magenta)
      width = ([ visible_width(title) + 4 ] + lines.map { |line| visible_width(line) }).max
      puts
      puts pastel.decorate("╭─ ", color) + pastel.decorate(title, color, :bold) + pastel.decorate(" #{"─" * (width - visible_width(title) - 1)}╮", color)
      lines.each do |line|
        puts pastel.decorate("│ ", color) + line + " " * (width - visible_width(line)) + pastel.decorate(" │", color)
      end
      puts pastel.decorate("╰#{"─" * (width + 2)}╯", color)
    end

    def visible_width(string)
      pastel.strip(string.to_s).length
    end
end
