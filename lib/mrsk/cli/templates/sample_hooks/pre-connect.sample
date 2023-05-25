#!/usr/bin/env ruby

# A sample pre-connect check
#
# Warms DNS before connecting to hosts in parallel
#
# These environment variables are available:
# MRSK_RECORDED_AT
# MRSK_PERFORMER
# MRSK_VERSION
# MRSK_HOSTS
# MRSK_ROLE (if set)
# MRSK_DESTINATION (if set)
# MRSK_RUNTIME

hosts = ENV["MRSK_HOSTS"].split(",")
results = nil
max = 3

elapsed = Benchmark.realtime do
  results = hosts.map do |host|
    Thread.new do
      tries = 1

      begin
        Socket.getaddrinfo(host, 0, Socket::AF_UNSPEC, Socket::SOCK_STREAM, nil, Socket::AI_CANONNAME)
      rescue SocketError
        if tries < max
          puts "Retrying DNS warmup: #{host}"
          tries += 1
          sleep rand
          retry
        else
          puts "DNS warmup failed: #{host}"
          host
        end
      end

      tries
    end
  end.map(&:value)
end

retries = results.sum - hosts.size
nopes = results.count { |r| r == max }

puts "Prewarmed %d DNS lookups in %.2f sec: %d retries, %d failures" % [ hosts.size, elapsed, retries, nopes ]
