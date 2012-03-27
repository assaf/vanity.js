PORT = 3000 # NOTE: use different port for each application
PID_FILE = "tmp/pow.pid"
RUN_SERVER = "npm start"
LOG_FILE = "log/development.log"


$stdout.reopen LOG_FILE, "a"
$stderr.reopen LOG_FILE, "a"


require "net/http"


class Server

  def initialize(port)
    @port = port
    # Need tmp directory to exist
    Dir.mkdir "tmp" unless File.exists?("tmp")
    # Read PID and check if process is alive
    pid = File.read(PID_FILE) rescue nil
    pid = `ps -o pid -p #{pid}`.split("\n")[1] if pid
    @pid = pid
  end

  def running?
    !!@pid
  end

  # Start the Web server
  def start
    return if running?
    $stdout.puts "Starting Web server with #{RUN_SERVER} ..."
    ENV["PORT"] = @port.to_s
    @pid = fork do
      exec RUN_SERVER
    end
    File.write PID_FILE, @pid
  end

  def shutdown
    return unless running?
    $stdout.puts "Shutting down Web server"
    kill_all @pid
    File.unlink "tmp/pow.pid" rescue nil
    @pid = nil
  end

  def call(env)
    begin
      request = Rack::Request.new(env)
      headers = {}
      env.each do |key, value|
        if key =~ /^http_(.*)/i
          headers[$1] = value
        end
      end
      headers["Content-Type"] = request.content_type if request.content_type
      headers["Content-Length"] = request.content_length if request.content_length
      headers["X-Forwarded-Host"] = request.host
      headers["User-Agent"] = request.user_agent
      http = Net::HTTP.new("localhost", @port.to_i)
      http.start do |http|
        response = http.send_request(request.request_method, request.fullpath, request.body.read, headers)
        headers = response.to_hash
        headers.delete "transfer-encoding"
        [response.code, headers, [response.body]]
      end
    rescue Errno::ECONNREFUSED
      $stderr.puts $!, $@
      [500, {}, ["Server is down, try $ npm start"]]
    end
  end

  # Used by shutdown to recursively terminate child processes
  def kill_all(pid)
    IO.popen("ps -xo pid,ppid | grep #{pid}").readlines.each do |line|
      child = line.split.first
      kill_all child if child && child != pid
    end
    Process.kill :KILL, pid.to_i rescue nil
  end

end


# Start server, shutdown when done
server = Server.new(ENV["PORT"] || PORT)
server.start
at_exit { server.shutdown }

# Run as Rack handler
sleep 3
run server
