require "socket"
require "fileutils"

dir = "/tmp/otel"
FileUtils.mkdir_p(dir)

server = TCPServer.new("0.0.0.0", 4318)

loop do
  client = server.accept
  request = ""
  content_length = 0

  while (line = client.gets) && line != "\r\n"
    request << line
    content_length = $1.to_i if line =~ /^Content-Length:\s*(\d+)/i
  end

  body = client.read(content_length) if content_length > 0

  if body && !body.empty?
    File.write("#{dir}/#{Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)}.json", body)
  end

  client.print "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
  client.close
end
