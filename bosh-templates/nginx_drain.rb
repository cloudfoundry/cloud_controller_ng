#!/var/vcap/packages/ruby/bin/ruby --disable-all

require "logger"
require "fileutils"

FileUtils.mkdir_p("/var/vcap/sys/log/nginx_ccng")
logger = Logger.new("/var/vcap/sys/log/nginx_ccng/drain.log")

logger.info("Drain script invoked with #{ARGV.join(" ")}")

nginx_pidfile = "/var/vcap/sys/run/nginx_ccng/nginx.pid"

if !File.exists?(nginx_pidfile)
  logger.info("Nginx not running")
  puts 0
  exit 0
end

begin
  nginx_pid = File.read(nginx_pidfile).to_i
  logger.info("Sending signal QUIT to Nginx.")
  Process.kill("QUIT", nginx_pid)
  logger.info("Hey BOSH, call me back in 5s.")
  puts(-5)
rescue Errno::ESRCH => e
  logger.info("Caught exception: #{e}")
  puts 0
end
