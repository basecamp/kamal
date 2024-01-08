module Kamal::Commands::App::Logging
  def logs(since: nil, lines: nil, grep: nil)
    pipe \
      current_running_container_id,
      "xargs docker logs#{" --since #{since}" if since}#{" --tail #{lines}" if lines} 2>&1",
      ("grep '#{grep}'" if grep)
  end

  def follow_logs(host:, lines: nil, grep: nil)
    run_over_ssh \
      pipe(
        current_running_container_id,
        "xargs docker logs --timestamps#{" --tail #{lines}" if lines} --follow 2>&1",
        (%(grep "#{grep}") if grep)
      ),
      host: host
  end
end
