#!/var/vcap/packages/ruby/bin/ruby --disable-all

require "logger"
require "fileutils"

# set up logging
def logger
  return @logger if @logger
  FileUtils.mkdir_p("/var/vcap/sys/log/drain")
  @logger = Logger.new("/var/vcap/sys/log/drain/drain.log")
end

def log_info(message)
  logger.info("cc.drain: #{message}")
end

log_info("#{__FILE__} invoked with #{ARGV.map{|x| x.inspect}.join(" ")}")

def is_alive(pidfile, program)
  if !File.exists?(pidfile)
    log_info("#{program} not running")
    return false
  end
  return true
end

def send_signal(pidfile, signal, program)
  pid = File.read(pidfile).to_i
  log_info("Sending signal #{signal} to #{program} with pid #{pid}.")
  Process.kill(signal, pid)
rescue Errno::ESRCH => e
  log_info("#{program} not running: Pid no longer exists: #{e}")
rescue Errno::ENOENT => e
  log_info("#{program} not running: Pid file no longer exists: #{e}")
end

def wait_for_pid(pidfile, timeout, interval)
  process_name = File.basename(pidfile)
  while is_alive(pidfile, process_name) && timeout > 0
    log_info("Waiting #{timeout}s for #{process_name} to shutdown")
    sleep(interval)
    timeout -= interval
  end
end

# unregister CC from router
ccng_pidfile = "/var/vcap/sys/run/cloud_controller_ng/cloud_controller_ng.pid"
send_signal(ccng_pidfile, "USR2", "cc_ng")
# wait for a while to make sure the routes are gone
# we don't get any real feedback from the  routers, so we have to just
# wait and assume the message made it.
timeout = 20
interval = 5
while timeout > 0 do
  log_info("Waiting for router unregister to have taken effect #{timeout} more seconds")
  sleep interval
  timeout -= interval
end

# request nginx graceful shutdown
nginx_pidfile = "/var/vcap/sys/run/nginx_ccng/nginx.pid"
send_signal(nginx_pidfile, "QUIT", "Nginx")
wait_for_pid(nginx_pidfile, 30, 3) # wait until nginx is shut down

# say drain script succeeded
# if the process is still running, monit will kill it ungracefully
puts 0
