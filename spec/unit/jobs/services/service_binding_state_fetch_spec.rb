require 'spec_helper'
require 'jobs/v2/services/service_binding_state_fetch'
require_relative 'shared/when_broker_returns_retry_after_header'

module VCAP::CloudController
  module Jobs
    module Services
      RSpec.describe ServiceBindingStateFetch, job_context: :worker do
        let(:operation_type) { 'create' }
        let(:service_binding_operation) { ServiceBindingOperation.make(state: 'in progress', type: operation_type) }
        let(:maximum_polling_duration_for_plan) {}
        let(:service_plan) { ServicePlan.make(maximum_polling_duration: maximum_polling_duration_for_plan) }
        let(:service_binding) do
          service_binding = ServiceBinding.make(service_instance: ManagedServiceInstance.make(service_plan: service_plan))
          service_binding.service_binding_operation = service_binding_operation
          service_binding
        end

        let(:max_duration) { 10080 }
        let(:default_polling_interval) { 60 }
        let(:user) { User.make }
        let(:user_email) { 'fake@mail.foo' }
        let(:user_info) { UserAuditInfo.new(user_guid: user.guid, user_email: user_email) }
        let(:request_attrs) do
          {
            some_attr: 'some_value'
          }
        end

        before do
          TestConfig.override({
            broker_client_default_async_poll_interval_seconds: default_polling_interval,
            broker_client_max_async_poll_duration_minutes: max_duration,
          })
        end

        def run_job(job)
          Jobs::Enqueuer.new(job, { queue: Jobs::Queues.generic, run_at: Delayed::Job.db_time_now }).enqueue
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end

        describe '#initialize' do
          let(:maximum_polling_duration_for_plan) { 36000000 } # in seconds
          let(:job) { VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new(service_binding.guid, user_info, request_attrs) }

          context 'when the service plan has maximum_polling_duration' do
            context "when the config value is smaller than plan's maximum_polling_duration" do
              let(:max_duration) { 10 } # in minutes
              it 'should set end_timestamp to config value' do
                Timecop.freeze(Time.now)
                expect(job.end_timestamp).to eq(Time.now + max_duration.minutes)
              end
            end

            context "when the config value is greater than plan's maximum_polling_duration" do
              let(:max_duration) { 1068367346 } # in minutes

              it "should set end_timestamp to the plan's maximum_polling_duration value" do
                Timecop.freeze(Time.now)
                expect(job.end_timestamp).to eq(Time.now + maximum_polling_duration_for_plan.seconds)
              end
            end
          end

          context 'when there is a database error in fetching the plan' do
            it 'should set end_timestamp to config value' do
              allow(ManagedServiceInstance).to receive(:first) do |e|
                raise Sequel::Error.new(e)
              end
              Timecop.freeze(Time.now)
              expect(job.end_timestamp).to eq(Time.now + max_duration.minutes)
            end
          end
        end

        describe '#perform' do
          let(:job) { VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new(service_binding.guid, user_info, request_attrs) }
          let(:state) { 'in progress' }
          let(:description) { '10%' }
          let(:last_operation_response) { { last_operation: { state: state, description: description } } }
          let(:client) { instance_double(VCAP::Services::ServiceBrokers::V2::Client) }

          before do
            allow(VCAP::Services::ServiceClientProvider).to receive(:provide).and_return(client)
            allow(client).to receive(:fetch_service_binding_last_operation).and_return(last_operation_response)
          end

          context 'when the last_operation type is create' do
            let(:operation_type) { 'create' }

            context 'when the last_operation state is succeeded' do
              let(:state) { 'succeeded' }
              let(:description) { '100%' }
              let(:binding_response) { {} }

              before do
                allow(client).to receive(:fetch_service_binding).with(service_binding).and_return(binding_response)
              end

              it 'should update the service binding operation' do
                run_job(job)
                service_binding.reload
                expect(service_binding.last_operation.state).to eq('succeeded')
              end

              context 'and the broker returns valid credentials' do
                before do
                  # executes job and enqueues another job
                  run_job(job)
                end

                let(:binding_response) { { credentials: { a: 'b' } } }

                it 'should not enqueue another fetch job' do
                  expect(Delayed::Job.count).to eq 0
                end

                it 'should update the service binding' do
                  service_binding.reload
                  expect(service_binding.credentials).to eq({ 'a' => 'b' })
                end
              end

              context 'and the broker returns a valid syslog_drain_url' do
                before do
                  # executes job and enqueues another job
                  run_job(job)
                end

                let(:binding_response) { { syslog_drain_url: 'syslog://example.com/awesome-syslog' } }

                it 'should not enqueue another fetch job' do
                  expect(Delayed::Job.count).to eq 0
                end

                it 'should update the service binding' do
                  service_binding.reload
                  expect(service_binding.syslog_drain_url).to eq('syslog://example.com/awesome-syslog')
                end
              end

              context 'and the broker returns a valid volume_mounts' do
                before do
                  # executes job and enqueues another job
                  run_job(job)
                end

                let(:binding_response) do
                  {
                    volume_mounts: [{
                      driver: 'cephdriver',
                      container_dir: '/data/images',
                      mode: 'r',
                      device_type: 'shared',
                      device: {
                        volume_id: 'bc2c1eab-05b9-482d-b0cf-750ee07de311',
                        mount_config: {
                          key: 'value'
                        }
                      }
                    }]
                  }
                end

                it 'should not enqueue another fetch job' do
                  expect(Delayed::Job.count).to eq 0
                end

                it 'should update the service binding' do
                  service_binding.reload
                  expect(service_binding.volume_mounts).to eq([{
                    'driver' => 'cephdriver',
                    'container_dir' => '/data/images',
                    'mode' => 'r',
                    'device_type' => 'shared',
                    'device' => {
                      'volume_id' => 'bc2c1eab-05b9-482d-b0cf-750ee07de311',
                      'mount_config' => {
                        'key' => 'value'
                      }
                    }
                  }])
                end
              end

              context 'and the broker returns invalid credentials' do
                let(:broker_response) {
                  VCAP::Services::ServiceBrokers::V2::HttpResponse.new(
                    code: '200',
                    body: {}.to_json,
                  )
                }
                let(:binding_response) { { credentials: 'invalid' } }
                let(:response_malformed_exception) { VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerResponseMalformed.new(nil, nil, broker_response, nil) }

                before do
                  allow(client).to receive(:fetch_service_binding).with(service_binding).and_raise(response_malformed_exception)
                end

                it 'should not enqueue another fetch job' do
                  run_job(job)

                  expect(Delayed::Job.count).to eq 0
                end

                it 'should not perform orphan mitigation' do
                  expect(client).not_to receive(:unbind)

                  run_job(job)
                end

                it 'should update the service binding last operation' do
                  run_job(job)

                  service_binding.reload
                  expect(service_binding.last_operation.state).to eq('failed')
                  expect(service_binding.last_operation.description).to eq('A valid binding could not be fetched from the service broker.')
                end

                it 'should never show service binding last operation succeeded' do
                  allow(client).to receive(:fetch_service_binding).with(service_binding) do |service_binding|
                    service_binding.reload
                    expect(service_binding.last_operation.state).to eq('in progress')

                    raise response_malformed_exception
                  end

                  run_job(job)

                  service_binding.reload
                  expect(service_binding.last_operation.state).to eq('failed')
                  expect(service_binding.last_operation.description).to eq('A valid binding could not be fetched from the service broker.')
                end

                it 'should not create an audit event' do
                  run_job(job)

                  expect(Event.all.count).to eq 0
                end
              end

              context 'and the broker returns with invalid status code' do
                let(:broker_response) {
                  VCAP::Services::ServiceBrokers::V2::HttpResponse.new(
                    code: '204',
                    body: {}.to_json,
                  )
                }
                let(:binding_response) { { credentials: '{}' } }
                let(:bad_response_exception) { VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerBadResponse.new(nil, nil, broker_response) }

                before do
                  allow(client).to receive(:fetch_service_binding).with(service_binding).and_raise(bad_response_exception)
                end

                it 'should not enqueue another fetch job' do
                  run_job(job)

                  expect(Delayed::Job.count).to eq 0
                end

                it 'should not perform orphan mitigation' do
                  expect(client).not_to receive(:unbind)

                  run_job(job)
                end

                it 'should update the service binding last operation' do
                  run_job(job)

                  service_binding.reload
                  expect(service_binding.last_operation.state).to eq('failed')
                  expect(service_binding.last_operation.description).to eq('A valid binding could not be fetched from the service broker.')
                end

                it 'should not create an audit event' do
                  run_job(job)

                  expect(Event.all.count).to eq 0
                end
              end

              context 'and the broker response timeout' do
                let(:broker_response) {
                  VCAP::Services::ServiceBrokers::V2::HttpResponse.new(
                    code: '204',
                    body: {}.to_json,
                  )
                }
                let(:binding_response) { { credentials: '{}' } }
                let(:timeout_exception) { VCAP::Services::ServiceBrokers::V2::Errors::HttpClientTimeout.new(nil, nil, broker_response) }

                before do
                  allow(client).to receive(:fetch_service_binding).with(service_binding).and_raise(timeout_exception)
                end

                it 'should not enqueue another fetch job' do
                  run_job(job)

                  expect(Delayed::Job.count).to eq 0
                end

                it 'should not perform orphan mitigation' do
                  expect(client).not_to receive(:unbind)

                  run_job(job)
                end

                it 'should update the service binding last operation' do
                  run_job(job)

                  service_binding.reload
                  expect(service_binding.last_operation.state).to eq('failed')
                  expect(service_binding.last_operation.description).to eq('A valid binding could not be fetched from the service broker.')
                end

                it 'should not create an audit event' do
                  run_job(job)

                  expect(Event.all.count).to eq 0
                end
              end

              context 'and the broker returns credentials and something else' do
                before do
                  run_job(job)
                end

                let(:binding_response) { { credentials: { a: 'b' }, parameters: { c: 'd' } } }

                it 'should update the service binding' do
                  service_binding.reload
                  expect(service_binding.credentials).to eq({ 'a' => 'b' })
                end
              end

              context 'when user information is provided' do
                before do
                  run_job(job)
                end

                it 'should create audit event' do
                  event = Event.find(type: 'audit.service_binding.create')
                  expect(event).to be
                  expect(event.actee).to eq(service_binding.guid)
                  expect(event.metadata['request']).to have_key('some_attr')
                end
              end

              context 'when the user has gone away' do
                it 'should create an audit event' do
                  allow(client).to receive(:fetch_service_binding).with(service_binding).and_return(binding_response)
                  user.destroy

                  run_job(job)

                  event = Event.find(type: 'audit.service_binding.create')
                  expect(event).to be
                  expect(event.actee).to eq(service_binding.guid)
                  expect(event.metadata['request']).to have_key('some_attr')
                end
              end

              context 'when during client call(to fetch last operation) the last operation on the service_binding was replaced' do
                before do
                  allow(client).to receive(:fetch_service_binding_last_operation) do
                    service_binding.save_with_new_operation(
                      {
                        type: 'delete',
                        state: 'in progress'
                      }
                    )

                    last_operation_response
                  end
                end

                it 'does not do anything' do
                  run_job(job)

                  reloaded_service_binding = ServiceBinding.first(guid: service_binding.guid)
                  expect(reloaded_service_binding).not_to be_nil
                  expect(Event.find(type: 'audit.service_instance.delete')).not_to be

                  expect(reloaded_service_binding.last_operation.state).not_to eq(state)
                end
              end
            end

            context 'when the last_operation state is in progress' do
              let(:description) { '50%' }
              let(:polling_interval) { 60 }

              before do
                TestConfig.config[:broker_client_default_async_poll_interval_seconds] = polling_interval
                run_job(job)
              end

              it 'should not create an audit event' do
                event = Event.find(type: 'audit.service_binding.create')
                expect(event).to be_nil
              end

              it 'should update the service binding operation' do
                service_binding.reload
                expect(service_binding.last_operation.description).to eq('50%')
              end

              context 'when the last_operation is replaced with delete in progress' do
                before do
                  service_binding.save_with_new_operation(type: 'delete', state: 'in progress')
                end

                it 'is able to run the job again' do
                  Timecop.travel(Time.now + polling_interval.seconds) do
                    execute_all_jobs(expected_successes: 1, expected_failures: 0)
                  end
                end
              end
            end

            context 'when the last_operation state is failed' do
              let(:state) { 'failed' }
              let(:description) { 'something went wrong' }

              before do
                run_job(job)
              end

              it 'updates the service binding last operation details' do
                service_binding.reload
                expect(service_binding.last_operation.state).to eq('failed')
                expect(service_binding.last_operation.description).to eq('something went wrong')
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end
            end

            context 'when enqueing the job reaches the max poll duration' do
              before do
                run_job(job)
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should mark the service instance operation as failed with appropriate description' do
                service_binding.reload

                expect(service_binding.last_operation.state).to eq('failed')
                expect(service_binding.last_operation.description).to eq('Service Broker failed to create binding within the required time.')
              end
            end
          end

          context 'when the last_operation type is delete' do
            let(:operation_type) { 'delete' }

            context 'when the last_operation state is succeeded' do
              let(:state) { 'succeeded' }
              let(:description) { '100%' }

              it 'deletes the binding' do
                service_binding_guid = service_binding.guid
                run_job(job)

                expect(ServiceBinding.find(guid: service_binding_guid)).to be_nil
              end

              context 'when user information is provided' do
                before do
                  run_job(job)
                end

                it 'should create audit event' do
                  event = Event.find(type: 'audit.service_binding.delete')
                  expect(event).not_to be_nil
                  expect(event.actee).to eq(service_binding.guid)
                end
              end

              context 'when the user has gone away' do
                it 'should create an audit event' do
                  user.destroy
                  run_job(job)

                  event = Event.find(type: 'audit.service_binding.delete')
                  expect(event).not_to be_nil
                  expect(event.actee).to eq(service_binding.guid)
                end
              end
            end

            context 'when the last operation state is succeeded' do
              let(:state) { 'succeeded' }
              let(:description) { '100%' }

              it 'deletes the binding' do
                service_binding_guid = service_binding.guid
                run_job(job)

                expect(ServiceBinding.find(guid: service_binding_guid)).to be_nil
              end

              it 'creates an audit event' do
                run_job(job)
                event = Event.find(type: 'audit.service_binding.delete')
                expect(event).not_to be_nil
                expect(event.actee).to eq(service_binding.guid)
              end
            end

            context 'when the last_operation state is in progress' do
              let(:description) { '50%' }

              before do
                run_job(job)
              end

              it 'should update the service binding operation' do
                service_binding.reload
                expect(service_binding.last_operation.description).to eq('50%')
              end

              it 'should not create an audit event' do
                event = Event.find(type: 'audit.service_binding.delete')
                expect(event).to be_nil
              end

              it 'should enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 1
                expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceBindingStateFetch)
              end
            end

            context 'when the last_operation state is failed' do
              let(:state) { 'failed' }
              let(:description) { 'something went wrong' }

              before do
                run_job(job)
              end

              it 'updates the service binding last operation details' do
                service_binding.reload
                expect(service_binding.last_operation.state).to eq('failed')
                expect(service_binding.last_operation.description).to eq('something went wrong')
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end

              it 'should not create an audit event' do
                event = Event.find(type: 'audit.service_binding.delete')
                expect(event).to be_nil
              end
            end

            context 'when enqueing the job reaches the max poll duration' do
              before do
                run_job(job)
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should mark the service instance operation as failed' do
                service_binding.reload

                expect(service_binding.last_operation.state).to eq('failed')
                expect(service_binding.last_operation.description).to eq('Service Broker failed to delete binding within the required time.')
              end
            end
          end

          context 'when the broker responds to last_operation' do
            before do
              # executes job and enqueues another job
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first).to be_a_fully_wrapped_job_of(ServiceBindingStateFetch)
            end

            it 'updates the binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
              expect(service_binding.last_operation.description).to eq('10%')
            end

            context 'when enqueing the job reaches the max poll duration' do
              before do
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end
            end
          end

          context 'when calling last operation responds without last_operation' do
            let(:last_operation_response) { {} }

            before do
              Jobs::Enqueuer.new(job, { queue: Jobs::Queues.generic, run_at: Delayed::Job.db_time_now }).enqueue
              Delayed::Worker.new.work_off
            end

            it 'raises informative error' do
              expect(Delayed::Job.first.last_error).to match(/Invalid response from client/)
            end

            it 'should not enqueue another fetch job in addition to the failed one' do
              expect(Delayed::Job.count).to eq 1
              expect(Delayed::Job.first.failed?).to be true
            end
          end

          context 'when calling last operation responds with an error HttpResponseError' do
            before do
              response = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: 412, body: {})
              err = HttpResponseError.new('oops', 'GET', response)
              allow(client).to receive(:fetch_service_binding_last_operation).and_raise(err)

              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end

            context 'and the max poll duration has been reached' do
              before do
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end
            end
          end

          context 'when calling last operation responds with an error HttpResponseError' do
            before do
              err = HttpRequestError.new('oops', 'uri', 'GET', RuntimeError.new)
              allow(client).to receive(:fetch_service_binding_last_operation).and_raise(err)

              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end

            context 'and the max poll duration has been reached' do
              before do
                Timecop.travel(Time.now + max_duration.minutes + 1.minute) do
                  # executes job but does not enqueue another job
                  execute_all_jobs(expected_successes: 1, expected_failures: 0)
                end
              end

              it 'should not enqueue another fetch job' do
                expect(Delayed::Job.count).to eq 0
              end
            end
          end

          context 'when last operation request times out on the broker' do
            before do
              err = VCAP::Services::ServiceBrokers::V2::Errors::ServiceBrokerApiTimeout.new('uri', 'GET', {})
              allow(client).to receive(:fetch_service_binding_last_operation).and_raise(err)
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end
          end

          context 'when the http call for last operation times out' do
            before do
              err = VCAP::Services::ServiceBrokers::V2::Errors::HttpClientTimeout.new('uri', 'GET', {})
              allow(client).to receive(:fetch_service_binding_last_operation).and_raise(err)
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end
          end

          context 'when a database operation fails' do
            let(:job) { VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new(service_binding.guid, user_info, request_attrs) }

            before do
              allow(ServiceBinding).to receive(:first).and_raise(Sequel::Error)
              run_job(job)
            end

            it 'should enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 1
            end

            it 'maintains the service binding last operation details' do
              service_binding.reload
              expect(service_binding.last_operation.state).to eq('in progress')
            end
          end

          context 'when the service binding has been purged' do
            let(:job) { VCAP::CloudController::Jobs::Services::ServiceBindingStateFetch.new('bad-binding-guid', user_info, request_attrs) }

            it 'successfully exits the job' do
              # executes job and enqueues another job
              run_job(job)
            end

            it 'should not enqueue another fetch job' do
              expect(Delayed::Job.count).to eq 0
            end
          end

          context 'when the poll_interval is changed after the job was created' do
            let(:new_polling_interval) { default_polling_interval * 2 }

            it 'updates the poll interval after the next run' do
              Timecop.freeze(Time.now)
              first_run_time = Time.now

              # Force job to be initialized now, before we modify the test config
              job
              TestConfig.override(broker_client_default_async_poll_interval_seconds: new_polling_interval)

              Jobs::Enqueuer.new(job, { queue: Jobs::Queues.generic, run_at: first_run_time }).enqueue
              execute_all_jobs(expected_successes: 1, expected_failures: 0)
              expect(Delayed::Job.count).to eq(1)

              old_next_run_time = first_run_time + default_polling_interval.seconds + 1.second
              Timecop.travel(old_next_run_time) do
                execute_all_jobs(expected_successes: 0, expected_failures: 0)
              end

              new_next_run_time = first_run_time + new_polling_interval.seconds + 1.second
              Timecop.travel(new_next_run_time) do
                execute_all_jobs(expected_successes: 1, expected_failures: 0)
              end
            end
          end

          include_examples 'when brokers return Retry-After header', :fetch_service_binding_last_operation
        end
      end
    end
  end
end
