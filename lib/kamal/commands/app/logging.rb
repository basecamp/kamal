module Kamal::Commands::App::Logging
  def logs(container_id: nil, timestamps: true, since: nil, lines: nil, grep: nil, grep_options: nil)
    pipe \
      container_id_command(container_id),
      "xargs docker logs#{" --timestamps" if timestamps}#{" --since #{since}" if since}#{" --tail #{lines}" if lines} 2>&1",
      ("grep '#{grep}'#{" #{grep_options}" if grep_options}" if grep)
  end

  def follow_logs(host:, container_id: nil, timestamps: true, lines: nil, grep: nil, grep_options: nil)
    run_over_ssh \
      pipe(
        container_id_command(container_id),
        "xargs docker logs#{" --timestamps" if timestamps}#{" --tail #{lines}" if lines} --follow 2>&1",
        (%(grep "#{grep}"#{" #{grep_options}" if grep_options}) if grep)
      ),
      host: host
  end

  private

  def container_id_command(container_id)
    case container_id
    when Array then container_id
    when String, Symbol then "echo #{container_id}"
    else current_running_container_id
    end
  end
end
