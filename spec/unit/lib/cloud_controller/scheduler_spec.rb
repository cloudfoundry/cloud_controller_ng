require 'spec_helper'
require 'cloud_controller/scheduler'

module VCAP::CloudController
  RSpec.describe Scheduler do
    describe '#start' do
      subject(:schedule) { Scheduler.new(config) }

      let(:clock) { instance_double(Clock, schedule_cleanup: nil, schedule_frequent_cleanup: nil) }
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
    end
  end
end
