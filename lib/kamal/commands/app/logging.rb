module Kamal::Commands::App::Logging
  def logs(version: nil, since: nil, lines: nil, grep: nil, context: nil)
    pipe \
      version ? container_id_for_version(version) : current_running_container_id,
      "xargs docker logs#{" --since #{since}" if since}#{" --tail #{lines}" if lines} 2>&1",
      ("grep '#{grep}'#{" -C #{context}" if context}" if grep)
  end

  def follow_logs(host:, lines: nil, grep: nil, context: nil)
    run_over_ssh \
      pipe(
        current_running_container_id,
        "xargs docker logs --timestamps#{" --tail #{lines}" if lines} --follow 2>&1",
        (%(grep "#{grep}"#{" -C #{context}" if context}) if grep)
      ),
      host: host
  end
end
