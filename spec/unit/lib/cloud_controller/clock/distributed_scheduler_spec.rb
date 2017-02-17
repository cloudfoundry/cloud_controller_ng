require 'spec_helper'
require 'cloud_controller/clock/distributed_scheduler'

module VCAP::CloudController
  RSpec.describe DistributedScheduler do
    it 'runs the passed block only once per intervals even when there are multiple schedulers' do
      allow(Clockwork).to receive(:every).and_yield(nil)

      threads = []
      counter = 0

      10.times do
        threads << Thread.new do
          DistributedScheduler.new.schedule_periodic_job name: 'bob', interval: 1.minute, fudge: 1.second do
            counter += 1
          end
        end
      end

      threads.each(&:join)
      expect(counter).to eq(1)
    end
  end
end
