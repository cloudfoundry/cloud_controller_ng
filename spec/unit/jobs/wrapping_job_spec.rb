require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe WrappingJob do
      describe '#error' do
        context 'when the wrapped job does not have the error method defined' do
          it 'should no raise an exception' do
            handler = Object.new
            job     = WrappingJob.new(handler)
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
            job     = WrappingJob.new(handler)
            expect {
              job.reschedule_at(job, 'foobar')
            }.to_not raise_error
          end
        end
      end

      describe '#before' do
        context 'when the wrapped job does not have the before method defined' do
          it 'should no raise an exception' do
            handler = Object.new
            job     = WrappingJob.new(handler)
            expect {
              job.before(job)
            }.to_not raise_error
          end
        end
      end

      describe '#success' do
        context 'when the wrapped job does not have the success method defined' do
          it 'should no raise an exception' do
            handler = Object.new
            job     = WrappingJob.new(handler)
            expect {
              job.success(job)
            }.to_not raise_error
          end
        end
      end

      describe '#failure' do
        context 'when the wrapped job does not have the failure method defined' do
          it 'should no raise an exception' do
            handler = Object.new
            job     = WrappingJob.new(handler)
            expect {
              job.failure(job)
            }.to_not raise_error
          end
        end
      end

      describe '#max_attempts' do
        context 'when the job does have max_attempts' do
          it 'return 1' do
            handler = double(:job, max_attempts: 3)
            job     = WrappingJob.new(handler)
            expect(job.max_attempts).to eq(3)
          end
        end

        context 'when the wrapped job does not have the max_attempts defined' do
          it 'return 1' do
            handler = Object.new
            job     = WrappingJob.new(handler)
            expect(job.max_attempts).to eq(1)
          end
        end
      end

      describe '#display_name' do
        subject(:wrapping_job) { WrappingJob.new(handler) }

        context 'when the handler implements #display_name' do
          let(:handler) { double(display_name: 'bob') }

          it 'delegates to the handler' do
            expect(wrapping_job.display_name).to eq(handler.display_name)
          end
        end

        context 'when the handler does not implement #display_name' do
          let(:handler) { Object.new }

          it 'returns the handler class name' do
            expect(wrapping_job.display_name).to eq('Object')
          end
        end
      end

      describe '#wrapped_handler' do
        subject(:wrapping_job) { WrappingJob.new(handler) }

        context 'when handler is a non-WrappedJob' do
          let(:handler) { double(:handler) }

          it 'returns the handler' do
            expect(wrapping_job.wrapped_handler).to eq(handler)
          end
        end

        context 'when handler is another WrappedJob' do
          let(:handler) { WrappingJob.new(wrapped_handler) }
          let(:wrapped_handler) { double(:handler) }

          it 'returns the leaf handler' do
            expect(wrapping_job.wrapped_handler).to eq(wrapped_handler)
          end
        end
      end
    end
  end
end
