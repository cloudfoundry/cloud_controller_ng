require 'spec_helper'
require 'cloud_controller/scheduler'

module VCAP::CloudController
  RSpec.describe Scheduler do
    describe '#start' do
      subject(:schedule) { Scheduler.new(config) }

      let(:clock) { instance_double(Clock, schedule_cleanup: nil, schedule_frequent_job: nil, schedule_daily: nil) }
      let(:config) { double }

      before do
        allow(Clock).to receive(:new).with(config).and_return(clock)
        allow(Clockwork).to receive(:run)
      end

      it 'runs Clockwork' do
        schedule.start

        expect(Clockwork).to have_received(:run)
      end

      it 'schedules cleanup for all daily jobs' do
        schedule.start

        Scheduler::CLEANUPS.map { |cleanup| cleanup[:class] }.each do |klass|
          expect(clock).to have_received(:schedule_cleanup).with(an_instance_of(Symbol), klass, an_instance_of(String))
        end
      end

      it 'schedules the frequent cleanup' do
        schedule.start

        expect(clock).to have_received(:schedule_frequent_job).
          with(:pending_droplets, Jobs::Runtime::PendingDropletCleanup)
      end

      it 'schedules diego syncs' do
        schedule.start

        expect(clock).to have_received(:schedule_frequent_job).
          with(:diego_sync, Jobs::Diego::Sync, priority: -10)
      end

      describe 'high availability' do
        let(:scheduler1) { Scheduler.new(config) }
        let(:scheduler2) { Scheduler.new(config) }

        it 'runs only one clock at a time' do
          allow(Clockwork).to receive(:run) { sleep 5 }

          schedulers = [
            Thread.new { scheduler1.start },
            Thread.new { scheduler2.start },
          ]
          schedulers.each { |t| t.join(0.5) }
          schedulers.each(&:kill)

          expect(Clockwork).to have_received(:run).once
        end
      end
    end
  end
end
