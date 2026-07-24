require "tty-spinner"

# Interactive renderer: each phase is a TTY::Spinner::Multi whose children are
# the participating hosts, so their spinners animate concurrently and then
# settle into ✔/✖ status lines when the phase resolves. The header, summary,
# and replay panels are inherited from the plain renderer unchanged.
class Kamal::Output::Console::TtyRenderer < Kamal::Output::Console::PlainRenderer
  SPINNER = :dots

  def phase(name)
    finish_multi
    puts
    @multi = TTY::Spinner::Multi.new(
      pastel.decorate("#{ARROW} #{name}", :bright_magenta, :bold),
      output: output, hide_cursor: true, format: SPINNER
    )
    @spinners = {}
  end

  def host_active(host)
    return unless @multi
    spinner = @multi.register(
      "[:spinner] #{host}",
      format: SPINNER,
      success_mark: pastel.green(OK),
      error_mark: pastel.red(FAIL)
    )
    @spinners[host] = spinner
    spinner.auto_spin
  end

  # tty-spinner has no safe way to print between its live spinners, so hold
  # notices raised during a phase and flush them once the phase resolves.
  def notice(message, color)
    line = color ? pastel.decorate(message, color) : message
    if @multi
      (@pending_notices ||= []) << line
    else
      puts line
    end
  end

  def end_phase(statuses)
    return super unless @multi

    statuses.each do |host, result|
      spinner = @spinners[host]
      next unless spinner

      if result[:status] == :failed
        spinner.error(pastel.red("failed"))
      else
        spinner.success(pastel.dim(format_duration(result[:duration])))
      end
    end

    finish_multi
  end

  private
    def finish_multi
      return unless @multi
      @spinners.each_value { |spinner| spinner.stop if spinner.spinning? }
      @multi = nil
      @spinners = {}
      flush_notices
    end

    def flush_notices
      return unless @pending_notices
      @pending_notices.each { |line| puts line }
      @pending_notices = nil
    end
end
