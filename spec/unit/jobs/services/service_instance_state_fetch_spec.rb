require 'spec_helper'

module VCAP::CloudController
  module Jobs
    module Services
      describe ServiceInstanceStateFetch do
        let(:client) { instance_double('VCAP::Services::ServiceBrokers::V2::Client') }
        let(:service_instance) do
          operation = ServiceInstanceOperation.make
          operation.save
          service_instance = ManagedServiceInstance.make
          service_instance.save

          service_instance.service_instance_operation = operation
          service_instance
        end

        let(:name) { 'fake-name' }

        let(:response) do
          {
            dashboard_url: 'url.com/dashboard',
            last_operation: {
              type: 'should-not-change',
              state: state,
              description: 'the description'
            },
          }
        end

        subject(:job) do
          VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
            name, {}, service_instance.guid
          )
        end

        def run_job(job)
          Jobs::Enqueuer.new(job, { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }).enqueue
          expect(Delayed::Worker.new.work_off).to eq [1, 0]
        end

        describe '#perform' do
          before do
            allow(VCAP::Services::ServiceBrokers::V2::Client).to receive(:new).and_return(client)
          end

          context 'when all operations succeed and the state is `succeeded`' do
            let(:state) { 'succeeded' }
            before do
              allow(client).to receive(:fetch_service_instance_state).and_return(response)
            end

            it 'fetches and updates the service instance state' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.state).to eq('succeeded')
              expect(db_service_instance.dashboard_url).to eq('url.com/dashboard')
            end

            it 'does not change the type field because of the broker' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.type).to eq('create')
            end

            it 'should not enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 0
            end
          end

          context 'when the state is `failed`' do
            let(:state) { 'failed' }
            before do
              allow(client).to receive(:fetch_service_instance_state).and_return(response)
            end

            it 'fetches and updates the service instance state' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.state).to eq('failed')
            end

            it 'should not enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 0
            end
          end

          context 'when all operations succeed, but the state is `in progress`' do
            let(:state) { 'in progress' }
            before do
              allow(client).to receive(:fetch_service_instance_state).and_return(response)
            end

            it 'fetches and updates the service instance state' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.state).to eq('in progress')
            end

            it 'should enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
            end
          end

          context 'when saving to the database fails' do
            let(:state) { 'in progress' }
            before do
              allow(client).to receive(:fetch_service_instance_state).and_return(response)
              allow(service_instance).to receive(:save) do |instance|
                raise Sequel::Error.new(instance)
              end
            end

            it 'should enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
            end
          end

          context 'when fetching the service instance from the broker fails' do
            before do
              allow(client).to receive(:fetch_service_instance_state).and_raise(error)
            end

            context 'due to an HttpRequestError' do
              let(:error) { VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout.new('some-uri.com', :get, nil) }
              it 'should enqueue another fetch job' do
                run_job(job)

                expect(Delayed::Job.count).to eq 1
                expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
              end
            end

            context 'due to an HttpResponseError' do
              let(:response) do
                instance_double(VCAP::Services::ServiceBrokers::V2::HttpResponse,
                  body: '{}',
                  code: 500,
                  message: 'Internal Server Error'
                )
              end
              let(:error) { VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new('some-uri.com', :get, response) }

              it 'should enqueue another fetch job' do
                job.perform

                expect(Delayed::Job.count).to eq 1
                expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)
              end
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
