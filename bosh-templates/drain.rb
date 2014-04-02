#!/var/vcap/packages/ruby/bin/ruby --disable-all

$LOAD_PATH.unshift("/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/app")
$LOAD_PATH.unshift("/var/vcap/packages/cloud_controller_ng/cloud_controller_ng/lib")

require "cloud_controller/drain"

@drain = VCAP::CloudController::Drain.new("/var/vcap/sys/log/cloud_controller_ng")
@drain.log_invocation(ARGV)
@drain.unregister_cc("/var/vcap/sys/run/cloud_controller_ng/cloud_controller_ng.pid")
@drain.shutdown_nginx("/var/vcap/sys/run/nginx_ccng/nginx.pid")

puts 0 # tell bosh the drain script succeeded
