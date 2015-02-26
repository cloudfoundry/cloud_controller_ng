require 'spec_helper'
require 'jobs/services/service_instance_state_fetch'

module VCAP::CloudController
  module Jobs
    module Services
      describe ServiceInstanceStateFetch do
        let(:broker) { ServiceBroker.make }
        let(:client_attrs) do
          {
            url: broker.broker_url,
            auth_username: broker.auth_username,
            auth_password: broker.auth_password,
          }
        end

        let(:proposed_service_plan) { ServicePlan.make }
        let(:service_instance) do
          operation = ServiceInstanceOperation.make(proposed_changes: {
            name: 'new-fake-name',
            service_plan_guid: proposed_service_plan.guid,
          })
          operation.save
          service_instance = ManagedServiceInstance.make
          service_instance.save

          service_instance.service_instance_operation = operation
          service_instance
        end

        let(:name) { 'fake-name' }

        let(:service_event_repository_opts) do
          {
            user_email: 'fake@mail.foo',
            user: User.make,
          }
        end

        let(:status) { 200 }
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
        let(:poll_interval) { 60.second }
        let(:request_attrs) do
          {
            dummy_data: 'dummy_data'
          }
        end

        subject(:job) do
          VCAP::CloudController::Jobs::Services::ServiceInstanceStateFetch.new(
            name, client_attrs, service_instance.guid, service_event_repository_opts, request_attrs, poll_interval
          )
        end

        def run_job(job)
          Jobs::Enqueuer.new(job, { queue: 'cc-generic', run_at: Delayed::Job.db_time_now }).enqueue
          expect(Delayed::Worker.new.work_off).to eq [1, 0]
        end

        describe '#initialize' do
          context 'when the caller provides a polling interval' do
            let(:default_polling_interval) { 120 }

            before do
              mock_enqueuer = double(:enqueuer, enqueue: nil)
              allow(VCAP::CloudController::Jobs::Enqueuer).to receive(:new).and_return(mock_enqueuer)
              allow(VCAP::CloudController::Config).to receive(:config).and_return({ broker_client_default_async_poll_interval_seconds: default_polling_interval })
            end

            context 'and the value is less than the default value' do
              let(:poll_interval) { 60 }

              it 'sets polling_interval to default polling interval' do
                expect(job.poll_interval).to eq default_polling_interval
              end
            end

            context 'and the value is greater than the max value (24 hours)' do
              let(:poll_interval) { 24.hours + 1.minute }

              it 'enqueues the job using the maximum polling interval' do
                expect(job.poll_interval).to eq 24.hours
              end
            end

            context 'and the value is between the default value and max value (24 hours)' do
              let(:poll_interval) { 200 }

              it 'enqueues the job using the broker provided polling interval' do
                expect(job.poll_interval).to eq poll_interval
              end
            end

            context 'when the default is greater than the max value (24 hours)' do
              let(:default_polling_interval) { 24.hours + 1.minute }
              let(:poll_interval) { 120 }

              it 'enqueues the job using the maximum polling interval' do
                expect(job.poll_interval).to eq 24.hours
              end
            end
          end
        end

        describe '#perform' do
          before do
            uri = URI(broker.broker_url)
            uri.user = broker.auth_username
            uri.password = broker.auth_password
            stub_request(:get, "#{uri}/v2/service_instances/#{service_instance.guid}").to_return(
              status: status,
              body: response.to_json
            )
          end

          context 'when all operations succeed and the state is `succeeded`' do
            let(:state) { 'succeeded' }

            context 'when the last operation type is `delete`' do
              before do
                service_instance.save_with_operation(
                  last_operation: {
                    type: 'delete',
                  },
                )
              end

              it 'should delete the service instance' do
                run_job(job)

                expect(ManagedServiceInstance.first(guid: service_instance.guid)).to be_nil
              end

              it 'should create a delete event' do
                run_job(job)

                event = Event.find(type: 'audit.service_instance.delete')
                expect(event).to be
              end
            end

            context 'when the last operation type is `update`' do
              before do
                service_instance.last_operation.type = 'update'
                service_instance.last_operation.save
              end

              it 'should create an update event' do
                run_job(job)

                event = Event.find(type: 'audit.service_instance.update')
                expect(event).to be
              end
            end

            it 'fetches and updates the service instance state' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.state).to eq('succeeded')
              expect(db_service_instance.dashboard_url).to eq('url.com/dashboard')
            end

            it 'applies the instance attributes that were proposed in the operation' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.service_plan).to eq(proposed_service_plan)
              expect(db_service_instance.name).to eq('new-fake-name')
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

            context 'when no user information is provided' do
              let(:service_event_repository_opts) { nil }

              it 'should not create an audit event' do
                run_job(job)

                expect(Event.find(type: 'audit.service_instance.create')).to be_nil
              end
            end

            context 'when user information is provided' do
              context 'and the last operation type is create' do
                it 'should create audit event' do
                  run_job(job)

                  event = Event.find(type: 'audit.service_instance.create')
                  expect(event).to be
                  expect(event.actee).to eq(service_instance.guid)
                  expect(event.metadata['request']).to eq({ 'dummy_data' => 'dummy_data' })
                end
              end
            end
          end

          context 'when the state is `failed`' do
            let(:state) { 'failed' }

            it 'does not apply the instance attributes that were proposed in the operation' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.service_plan).to_not eq(proposed_service_plan)
              expect(db_service_instance.name).to eq(service_instance.name)
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

            it 'should not create an audit event' do
              run_job(job)

              expect(Event.find(type: 'audit.service_instance.create')).to be_nil
            end
          end

          context 'when all operations succeed, but the state is `in progress`' do
            let(:state) { 'in progress' }

            it 'fetches and updates the service instance state' do
              run_job(job)

              db_service_instance = ManagedServiceInstance.first(guid: service_instance.guid)
              expect(db_service_instance.last_operation.state).to eq('in progress')
            end

            it 'should enqueue another fetch job' do
              run_job(job)

              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceInstanceStateFetch)

              Timecop.freeze(Time.now + 1.hour) do
                Delayed::Job.last.invoke_job
                expect(Delayed::Worker.new.work_off).to eq([1, 0])
              end
            end

            it 'should not create an audit event' do
              run_job(job)

              expect(Event.find(type: 'audit.service_instance.create')).to be_nil
            end
          end

          context 'when saving to the database fails' do
            let(:state) { 'in progress' }
            before do
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
            let(:status) { 500 }
            let(:response) { {} }

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
