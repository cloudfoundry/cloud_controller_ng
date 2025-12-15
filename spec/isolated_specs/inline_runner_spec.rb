require 'spec_helper'
require 'cloud_controller/clock/inline_runner'

########### Note ###########
# This test modifies the global setting Delayed::Worker.delay_jobs which might affect other tests running in parallel
# It is recommended to run this test separately
############################

module VCAP::CloudController
  RSpec.describe Jobs::InlineRunner, job_context: :clock do
    before(:all) do
      @original_delay_jobs = Delayed::Worker.delay_jobs
    end

    after(:all) do
      Delayed::Worker.delay_jobs = @original_delay_jobs
    end

    before do
      Delayed::Worker.delay_jobs = nil
    end

    describe '#setup' do
      it 'sets up delay_jobs' do
        expect(Delayed::Worker.delay_jobs).to be_nil

        Jobs::InlineRunner.setup

        expect(Delayed::Worker.delay_jobs).to be_instance_of(Proc)
      end
    end

    describe '#run' do
      let(:job) { double('inline_job', inline?: true, perform: nil) }
      let(:timeout) { 123 }
      let(:opts) { { queue: 'queue' } }

      before do
        Jobs::InlineRunner.setup
      end

      it 'calls Delayed::Job.enqueue with the job wrapped in a TimeoutJob' do
        expect_any_instance_of(Jobs::InlineRunner).to receive(:job_timeout).with(job).and_return(timeout)
        expect(Jobs::TimeoutJob).to receive(:new).with(job, timeout).and_call_original
        expect(Delayed::Job).to receive(:enqueue).with(instance_of(Jobs::TimeoutJob), opts).and_call_original
        expect(Delayed::Worker).to receive(:delay_job?).and_wrap_original do |method, *args|
          result = method.call(*args)
          expect(result).to be(false)
          result
        end
        expect(job).to receive(:perform)

        Jobs::InlineRunner.new(opts).run(job)
      end

      context 'when the job does not define inline?' do
        let(:job) { double('non_inline_job') }

        it 'raises an ArgumentError' do
          expect { Jobs::InlineRunner.new.run(job) }.to raise_error(ArgumentError, "job must define a method 'inline?' which returns 'true'")
        end
      end
    end
  end
end
