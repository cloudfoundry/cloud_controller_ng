#!/var/vcap/packages/ruby/bin/ruby --disable-all

require "logger"
require "fileutils"

unregister_wait_timeout = 20 # because we don't know when/wheter the router has acted on the unregister message
unregister_wait_interval = 5

nginx_timeout = 30
nginx_interval = 3

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
while unregister_wait_timeout > 0 do
  log_info("Waiting for router unregister to have taken effect #{unregister_wait_timeout} more seconds")
  sleep unregister_wait_interval
  unregister_wait_timeout -= unregister_wait_interval
end

# request nginx graceful shutdown
nginx_pidfile = "/var/vcap/sys/run/nginx_ccng/nginx.pid"
send_signal(nginx_pidfile, "QUIT", "Nginx")
wait_for_pid(nginx_pidfile, nginx_timeout, nginx_interval) # wait until nginx is shut down

puts 0 # tell bosh the drain script succeeded
