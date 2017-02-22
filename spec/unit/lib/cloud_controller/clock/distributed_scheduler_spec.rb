require 'spec_helper'
require 'cloud_controller/clock/distributed_scheduler'

module VCAP::CloudController
  RSpec.describe DistributedScheduler do
    it 'runs a distributed executor job every interval' do
      allow(Clockwork).to receive(:every).and_yield(nil).and_yield(nil)
      executor = instance_double(DistributedExecutor).as_null_object
      allow(DistributedExecutor).to receive(:new).and_return executor

      DistributedScheduler.new.schedule_periodic_job name: 'my-job', interval: 1.minute, fudge: 1.second

      expect(Clockwork).to have_received(:every).with(1.minute, 'my-job.job', {})
      expect(executor).to have_received(:execute_job).twice.with(name: 'my-job', interval: 1.minute, fudge: 1.second, timeout: nil)
    end

    it 'passes through thread, at, and timeout' do
      allow(Clockwork).to receive(:every).and_yield(nil)
      executor = instance_double(DistributedExecutor).as_null_object
      allow(DistributedExecutor).to receive(:new).and_return executor

      DistributedScheduler.new.schedule_periodic_job name: 'my-job', interval: 1.minute, fudge: 1.second, thread: true, at: Time.at(0), timeout: 3.minutes

      expect(Clockwork).to have_received(:every).with(1.minute, 'my-job.job', { at: Time.at(0), thread: true })
      expect(executor).to have_received(:execute_job).with(name: 'my-job', interval: 1.minute, fudge: 1.second, timeout: 3.minutes)
    end
  end
end
