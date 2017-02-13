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

      it 'configures Clockwork with a logger' do
        error = StandardError.new 'Boom!'
        allow(Clockwork).to receive(:error_handler).and_yield(error)
        expect_any_instance_of(Steno::Logger).to receive(:error).with(error)

        schedule.start
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
          with(:diego_sync, Jobs::Diego::Sync, priority: -10, queue: 'sync-queue', allow_only_one_job_in_queue: true)
      end
    end
  end
end
