require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe WrappingJob do
      describe '#error' do
        context 'when the wrapped job does not have the error method defined' do
          it 'should no raise an exception' do
            handler = Object.new
            job = WrappingJob.new(handler)
            expect {
              job.error(job, 'foobar')
            }.to_not raise_error
          end
        end
      end

      describe '#reschedule_at' do
        context 'when the wrapped job does not have the reschedule_at method defined' do
          it 'should no raise an exception' do
            handler = Object.new
            job = WrappingJob.new(handler)
            expect {
              job.reschedule_at(job, 'foobar')
            }.to_not raise_error
          end
        end
      end

      describe '#max_attempts' do
        context 'when the job does have max_attempts' do
          it 'return 1' do
            handler = double(:job, max_attempts: 3)
            job = WrappingJob.new(handler)
            expect(job.max_attempts).to eq(3)
          end
        end

        context 'when the wrapped job does not have the max_attempts defined' do
          it 'return 1' do
            handler = Object.new
            job = WrappingJob.new(handler)
            expect(job.max_attempts).to eq(1)
          end
        end
      end
    end
  end
end
