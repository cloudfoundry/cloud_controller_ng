require 'clockwork'
require 'cloud_controller/clock/distributed_executor'

module VCAP::CloudController
  class DistributedScheduler
    def schedule_periodic_job(name:, interval:, at: nil, thread: nil, fudge:, timeout: nil)
      clock_opts      = {}
      clock_opts[:at] = at if at
      clock_opts[:thread] = thread if thread

      Clockwork.every(interval, "#{name}.job", clock_opts) do |_|
        DistributedExecutor.new.execute_job(name: name, interval: interval, fudge: fudge, timeout: timeout) { yield }
      end
    end
  end
end
