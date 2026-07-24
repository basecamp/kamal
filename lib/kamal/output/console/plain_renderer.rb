# Line-based renderer for non-TTY output (CI, piped, redirected). No cursor
# movement or spinners: phases and per-host results are printed in order as
# they resolve, so the log stays clean and deterministic.
class Kamal::Output::Console::PlainRenderer < Kamal::Output::Console::Renderer
  def header(command:, service:, version:, destination:, hosts:, roles:)
    target = [ service, version ].compact.join("@")
    scope = "#{hosts} #{"host".pluralize(hosts)}, #{roles} #{"role".pluralize(roles)}"
    scope += " · #{destination}" if destination
    panel(command, [ "#{target} → #{scope}" ])
  end

  def phase(name)
    puts
    puts pastel.decorate("#{ARROW} #{name}", :bright_magenta, :bold)
  end

  def end_phase(statuses)
    statuses.each do |host, result|
      if result[:status] == :failed
        puts "  #{pastel.red(FAIL)} #{host}  #{pastel.red("failed")}"
      else
        puts "  #{pastel.green(OK)} #{host}  #{pastel.dim(format_duration(result[:duration]))}"
      end
    end
  end

  def notice(message, color)
    puts color ? pastel.decorate(message, color) : message
  end

  def summary(ok:, failed:, needs_attention:, runtime:, exception:)
    counts = [ pastel.green("#{OK} #{ok} ok") ]
    counts << pastel.red("#{FAIL} #{failed} failed") if failed > 0
    lines = [ "#{counts.join("   ")}   #{pastel.dim(format_duration(runtime))}" ]
    lines << pastel.red("needs attention: #{needs_attention.join(", ")}") if needs_attention.any?
    panel("Summary", lines, color: failed > 0 ? :red : :green)
  end

  def replay(host, lines)
    puts
    puts pastel.dim("── retained output · #{host} ─────")
    lines.each { |line| puts pastel.dim("#{BAR} ") + line }
  end

  private
    def format_duration(seconds)
      return "" unless seconds
      "#{sprintf("%.1f", seconds)}s"
    end
end
