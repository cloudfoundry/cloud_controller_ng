require 'spec_helper'

module VCAP::CloudController
  module Jobs::Services
    describe ServiceInstanceStateFetch do
      let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }
      let(:enqueuer) { instance_double('VCAP::CloudController::Jobs::Enqueuer') }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make }

      let(:name) { 'fake-name' }

      subject(:job) do
        VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(name, {},
          service_instance.guid, service_instance.service_plan.guid)
      end

      describe '#perform' do
        before do
          allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(client)
          allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(enqueuer)
          allow(enqueuer).to receive(:enqueue)
        end

        context 'when all operations succeed and the state is available' do
          before do
            allow(client).to receive(:fetch_service_instance_state) do |instance|
              instance.state = 'available'
            end
          end

          it 'fetches the service instance state' do
            job.perform

            expect(client).to have_received(:fetch_service_instance_state) do |instance|
              expect(instance.guid).to eq service_instance.guid
              expect(instance.service_plan.guid).to eq service_instance.service_plan.guid
            end

            db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
            expect(db_service_instance.state).to eq('available')
          end

          it 'should not enqueue another fetch job' do
            job.perform

            expect(VCAP::CloudController::Jobs::Enqueuer).to_not have_received(:new)
          end
        end

        context 'when all operations succeed, but the state is not available' do
          before do
            allow(client).to receive(:fetch_service_instance_state) do |instance|
              instance.state = 'creating'
            end
          end

          it 'fetches the service instance state' do
            job.perform

            expect(client).to have_received(:fetch_service_instance_state) do |instance|
              expect(instance.guid).to eq service_instance.guid
              expect(instance.service_plan.guid).to eq service_instance.service_plan.guid
            end

            db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
            expect(db_service_instance.state).to eq('creating')
          end

          it 'should enqueue another fetch job' do
            job.perform

            expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new).with(job, anything)
            expect(enqueuer).to have_received(:enqueue)
          end
        end

        context 'when saving to the database fails' do
          before do
            allow(client).to receive(:fetch_service_instance_state)
            allow(service_instance).to receive(:save) do |instance|
              raise Sequel::ValidationFailed.new(instance)
            end
          end

          it 'should enqueue another fetch job' do
            job.perform

            expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new).with(job, anything)
            expect(enqueuer).to have_received(:enqueue)
          end
        end

        context 'when fetching the service instance from the broker fails' do
          before do
            allow(client).to receive(:fetch_service_instance_state) do |instance|
              error = nil
              raise HttpRequestError.new('something', '/some/path', :get, error)
            end
          end

          it 'should enqueue another fetch job' do
            job.perform

            expect(VCAP::CloudController::Jobs::Enqueuer).to have_received(:new).with(job, anything)
            expect(enqueuer).to have_received(:enqueue)
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
