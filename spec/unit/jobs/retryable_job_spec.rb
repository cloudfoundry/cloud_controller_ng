require 'spec_helper'

module VCAP::CloudController
  module Jobs
    describe "RetryableJob" do
      describe '#perform' do
        let(:job) { double(:job, perform: nil) }
        let(:retryable_job) { RetryableJob.new(job) }

        it 'performs the job' do
          retryable_job.perform
          expect(job).to have_received(:perform)
        end

        context 'when the inner job fails' do
          let(:mock_response) { double(:response, body: nil, message: nil, code: 500) }
          before do
            allow(job).to receive(:perform).and_raise(error)
            allow(Delayed::Job).to receive(:enqueue)
          end

          context 'when the exception is ServiceBrokerApiTimeout' do
            let(:error) {  VCAP::Services::ServiceBrokers::V2::ServiceBrokerApiTimeout.new('uri.com', :delete, mock_response) }

            it 'enqueues another retryable job' do
              retryable_job.perform

              expect(Delayed::Job).to have_received(:enqueue) do |enqueued_job, opts|
                expect(enqueued_job).to be_a RetryableJob
                expect(enqueued_job.num_attempts).to eq 1
                expect(opts).to include(queue: 'cc-generic', run_at: anything)
              end
            end
          end

          context 'when the exception is ServiceBrokerBadResponse' do
            let(:error) {  VCAP::Services::ServiceBrokers::V2::ServiceBrokerBadResponse.new('uri.com', :delete, mock_response) }

            it 'enqueues another retryable job' do
              retryable_job.perform

              expect(Delayed::Job).to have_received(:enqueue) do |enqueued_job, opts|
                expect(enqueued_job).to be_a RetryableJob
                expect(enqueued_job.num_attempts).to eq 1
                expect(opts).to include(queue: 'cc-generic', run_at: anything)
              end
            end
          end

          describe 'exponential backoff' do
            let(:error) {  VCAP::Services::ServiceBrokers::V2::ServiceBrokerApiTimeout.new('uri.com', :delete, mock_response) }
            let(:retryable_job) { RetryableJob.new(job, num_attempts) }
            let(:num_attempts) { 5 }

            it 'runs the subsequent job at 2^(num_attempts) minutes from now' do
              now = Time.now
              Timecop.freeze now do
                retryable_job.perform

                expect(Delayed::Job).to have_received(:enqueue) do |enqueued_job, opts|
                  expect(enqueued_job.num_attempts).to eq(num_attempts + 1)
                  run_at = opts[:run_at]
                  expect(run_at).to be_within(0.01).of(now + (2 ** num_attempts).minutes)
                end
              end
            end

            context 'when the max attempts have reached' do
              let(:retryable_job) { RetryableJob.new(job, 10) }
              let(:error) {  VCAP::Services::ServiceBrokers::V2::ServiceBrokerApiTimeout.new('uri.com', :delete, mock_response) }

              it 'progagates an error' do
                expect {
                  retryable_job.perform
                }.to raise_error(VCAP::Services::ServiceBrokers::V2::ServiceBrokerApiTimeout)
              end
            end
          end
        end
      end
    end
  end
end


