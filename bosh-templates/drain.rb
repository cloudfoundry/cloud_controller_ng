#!/var/vcap/packages/ruby/bin/ruby --disable-all

require "logger"
require "fileutils"

def is_alive(pidfile, program)
  if !File.exists?(pidfile)
    $logger.info("#{program} not running")
    return false
  end
  return true
end

def send_signal(pidfile, signal, program)
  pid = File.read(pidfile).to_i
  $logger.info("Sending signal #{signal} to #{program} with pid #{pid}.")
  Process.kill(signal, pid)
rescue Errno::ESRCH => e
  $logger.info("#{program} not running: Pid no longer exists: #{e}")
rescue Errno::ENOENT => e
  $logger.info("#{program} not running: Pid file no longer exists: #{e}")
end

# set up logging
FileUtils.mkdir_p("/var/vcap/sys/log/drain")
$logger = Logger.new("/var/vcap/sys/log/drain/drain.log")
$logger.info("Drain script invoked with #{ARGV.join(" ")}")

# unregister CC from router
ccng_pidfile = "/var/vcap/sys/run/cloud_controller_ng/cloud_controller_ng.pid"
send_signal(ccng_pidfile, "USR2", "cc_ng")
sleep(20) # wait for a while to make sure the routes are gone

# request nginx graceful shutdown
nginx_pidfile = "/var/vcap/sys/run/nginx_ccng/nginx.pid"
send_signal(nginx_pidfile, "QUIT", "Nginx")

#wait until nginx is shut down
seconds_until_timeout = 30
check_in_interval = 3
while is_alive(nginx_pidfile, "Nginx") && seconds_until_timeout > 0
  sleep(check_in_interval)
  seconds_until_timeout -= check_in_interval
end

# say drain script succeeded
# if the process is still running, monit will kill it ungracefully
puts 0
