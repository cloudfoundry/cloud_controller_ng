require 'spec_helper'

module VCAP::CloudController
  module Jobs
    module Services
      describe ServiceInstanceStateFetch do
        let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }
        let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(state: 'unset') }

        let(:name) { 'fake-name' }

        subject(:job) do
          VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
            name, {}, service_instance.guid
          )
        end

        describe '#perform' do
          before do
            allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(client)
          end

          context 'when all operations succeed and the state is `succeeded`' do
            before do
              allow(client).to receive(:fetch_service_instance_state).
                and_return(state: 'succeeded', dashboard_url: 'my-dash')
            end

            it 'fetches and updates the service instance state' do
              job.perform

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.state).to eq('succeeded')
              expect(db_service_instance.dashboard_url).to eq('my-dash')
            end

            it 'should not enqueue another fetch job' do
              job.perform

              expect(Delayed::Job.count).to eq 0
            end
          end

          context 'when the state is `failed`' do
            before do
              allow(client).to receive(:fetch_service_instance_state).
                and_return(state: 'failed')
            end

            it 'fetches and updates the service instance state' do
              job.perform

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.state).to eq('failed')
            end

            it 'should not enqueue another fetch job' do
              job.perform

              expect(Delayed::Job.count).to eq 0
            end
          end

          context 'when all operations succeed, but the state is not `succeeded`' do
            before do
              allow(client).to receive(:fetch_service_instance_state).
                and_return(state: 'in progress')
            end

            it 'fetches and updates the service instance state' do
              job.perform

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.state).to eq('in progress')
            end

            it 'should enqueue another fetch job' do
              job.perform

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
            end
          end

          context 'when saving to the database fails' do
            before do
              allow(client).to receive(:fetch_service_instance_state).
                and_return(state: 'in progress')
              allow(service_instance).to receive(:save) do |instance|
                raise Sequel::Error.new(instance)
              end
            end

            it 'should enqueue another fetch job' do
              job.perform

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
            end
          end

          context 'when fetching the service instance from the broker fails' do
            before do
              nested_error = nil
              error = HttpRequestError.new('something', '/some/path', :get, nested_error)
              allow(client).to receive(:fetch_service_instance_state).and_raise(error)
            end

            it 'should enqueue another fetch job' do
              job.perform

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
            end
          end
        end

        describe '#job_name_in_configuration' do
          it 'returns the name of the job' do
            expect(job.job_name_in_configuration).to eq(:service_instance_state_fetch)
          end
        end

        describe '#max_attempts' do
          it 'returns 1' do
            expect(job.max_attempts).to eq(1)
          end
        end
      end
    end
  end
end
