require 'spec_helper'
require 'cloud_controller/clock'

module VCAP::CloudController
  RSpec.describe Clock do
    subject(:clock) { Clock.new(config) }

    let(:some_class) { Class.new { def initialize(_); end } }
    let(:enqueuer) { instance_double(Jobs::Enqueuer, enqueue: nil) }

    before do
      allow(Clockwork).to receive(:every).and_yield('dummy.scheduled.job')
      allow(Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
    end

    describe 'scheduling a cleanup event' do
      let(:config) { { some_name: { cutoff_age_in_days: 31 } } }

      it 'schedules it, and it schedules it on the cc-generic queue' do
        clock.schedule_cleanup(:some_name, some_class, '14:00')

        expect(Jobs::Enqueuer).to have_received(:new).with(anything, { queue: 'cc-generic' })
        expect(enqueuer).to have_received(:enqueue)
      end

      it 'schedules it at the appropriate time' do
        clock.schedule_cleanup(:some_name, some_class, '14:00')

        expect(Clockwork).to have_received(:every).with(1.day, 'some_name.cleanup.job', at: '14:00')
      end

      it 'enqueues the requested job class' do
        clock.schedule_cleanup(:some_name, some_class, '14:00')

        expect(Jobs::Enqueuer).to have_received(:new).with(an_instance_of(some_class), anything)
      end

      it 'configures the job with cutoff_age_in_days from the config' do
        allow(some_class).to receive(:new)

        clock.schedule_cleanup(:some_name, some_class, '14:00')

        expect(some_class).to have_received(:new).with(31)
      end

      it 'logs the queuing' do
        logger = instance_double(Steno::Logger, info: nil)
        allow(Steno).to receive(:logger).with('cc.clock').and_return(logger)

        clock.schedule_cleanup(:some_name, some_class, '14:00')

        expect(logger).to have_received(:info).with(/Queueing/)
      end
    end

    describe 'scheduling a frequent job' do
      let(:config) { { some_name: { frequency_in_seconds: 507, expiration_in_seconds: 203 } } }

      it 'schedules it, and it schedules it on the cc-generic queue' do
        clock.schedule_frequent_job(:some_name, some_class)

        expect(Jobs::Enqueuer).to have_received(:new).with(anything, { queue: 'cc-generic' })
        expect(enqueuer).to have_received(:enqueue)
      end

      it 'schedules it at the appropriate time' do
        clock.schedule_frequent_job(:some_name, some_class)

        expect(Clockwork).to have_received(:every).with(507, 'some_name.job')
      end

      it 'schedules it at the appropriate priority' do
        clock.schedule_frequent_job(:some_name, some_class, priority: -123)

        expect(Jobs::Enqueuer).to have_received(:new).with(anything, { priority: -123, queue: 'cc-generic' })
        expect(enqueuer).to have_received(:enqueue)
      end

      it 'enqueues the requested job class' do
        clock.schedule_frequent_job(:some_name, some_class)

        expect(Jobs::Enqueuer).to have_received(:new).with(an_instance_of(some_class), anything)
      end

      it 'configures the job with expiration_in_seconds from the config' do
        allow(some_class).to receive(:new)

        clock.schedule_frequent_job(:some_name, some_class)

        expect(some_class).to have_received(:new).with(203)
      end

      it 'logs the queuing' do
        logger = instance_double(Steno::Logger, info: nil)
        allow(Steno).to receive(:logger).with('cc.clock').and_return(logger)

        clock.schedule_frequent_job(:some_name, some_class)

        expect(logger).to have_received(:info).with(/Queueing/)
      end

      context 'without setting an expriation' do
        let(:config) { { some_name: { frequency_in_seconds: 507 } } }
        let(:some_class) { Class.new }

        it 'schedules it, and it schedules it on the cc-generic queue' do
          clock.schedule_frequent_job(:some_name, some_class)

          expect(Jobs::Enqueuer).to have_received(:new).with(some_class, { queue: 'cc-generic' })
          expect(enqueuer).to have_received(:enqueue)
        end
      end
    end
  end
end
