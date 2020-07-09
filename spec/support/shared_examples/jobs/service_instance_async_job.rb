RSpec.shared_examples 'service instance reocurring job' do |operation_type, client_response, api_error_code|
  describe 'when the broker client response is asynchronous' do
    let(:broker_response) {
      {
        instance: { dashboard_url: 'example.foo' },
        last_operation: {
          type: operation_type,
          state: 'in progress',
          description: 'abc',
          broker_provided_operation: 'task1',
        }
      }
    }

    let(:in_progress_last_operation) { { last_operation: { state: 'in progress' } } }
    let(:operation_type_client_method) {
      case operation_type
      when 'update'
        :update
      when 'delete'
        :deprovision
      else
        :provision
      end
    }

    before do
      allow(client).to receive(operation_type_client_method).and_return(client_response.call(broker_response))
      allow(client).to receive(:fetch_service_instance_last_operation).and_return(in_progress_last_operation)
      run_job(job, jobs_succeeded: 1, jobs_to_execute: 1)
    end

    it 'updates the last operation and job' do
      service_instance.reload
      expect(service_instance.last_operation.type).to eq(operation_type)
      expect(service_instance.last_operation.state).to eq('in progress')
      expect(service_instance.last_operation.description).to eq('abc')

      pollable_job = VCAP::CloudController::PollableJobModel.last
      expect(pollable_job.resource_guid).to eq(service_instance.guid)
      expect(pollable_job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
    end

    it 'immediately asks for a progress update' do
      expect(client).to have_received(:fetch_service_instance_last_operation).with(service_instance)
    end

    it 'sends the request to the broker' do
      broker_request_expect
    end

    context 'waiting for broker to finish' do
      context 'when a retry_after header is returned' do
        let(:in_progress_last_operation) do
          {
            last_operation: { state: 'in progress', description: 'abc' },
            retry_after: 430,
          }
        end

        it 'updates the polling interval' do
          Timecop.freeze(Time.now + 420.seconds) do
            execute_all_jobs(expected_successes: 0, expected_failures: 0)
          end

          Timecop.freeze(Time.now + 440.seconds) do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
          end
        end
      end

      context 'polling the last operation' do
        let(:description) { 'doing stuff' }

        let(:in_progress_last_operation_2) { { last_operation: { state: 'in progress', description: 'doing stuff' } } }

        before do
          allow(client).to receive(:fetch_service_instance_last_operation).and_return(in_progress_last_operation_2)

          Timecop.travel(job.polling_interval_seconds + 1.second)
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
        end

        it 'calls the last operation endpoint only' do
          expect(client).to have_received(operation_type_client_method).once
          expect(client).to have_received(:fetch_service_instance_last_operation).twice
        end

        it 'updates the description' do
          expect(service_instance.reload.last_operation.description).to eq('doing stuff')
        end

        context 'when there is no description' do
          let(:in_progress_last_operation_2) { { last_operation: { state: 'in progress' } } }

          it 'leaves the original description' do
            expect(service_instance.reload.last_operation.description).to eq('abc')
          end
        end

        context 'when the description is long (mysql)' do
          let(:long_description) { '123' * 512 }
          let(:in_progress_last_operation_2) { { last_operation: { state: 'in progress', description: long_description } } }

          it 'updates the description' do
            expect(service_instance.reload.last_operation.description).to eq(long_description)
          end
        end

        context 'when fetching the last operation from the broker fails' do
          context 'due to an HttpRequestError' do
            before do
              err = HttpRequestError.new('oops', 'uri', 'GET', RuntimeError.new)
              allow(client).to receive(:fetch_service_instance_last_operation).and_raise(err)
            end

            it 'should continue' do
              Timecop.travel(job.polling_interval_seconds + 1.second)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(Delayed::Job.count).to eq 1
            end
          end

          context 'due to an HttpResponseError' do
            before do
              response = VCAP::Services::ServiceBrokers::V2::HttpResponse.new(code: 412, body: {})
              err = HttpResponseError.new('oops', 'GET', response)
              allow(client).to receive(:fetch_service_instance_last_operation).and_raise(err)
            end

            it 'should continue' do
              Timecop.travel(job.polling_interval_seconds + 1.second)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(Delayed::Job.count).to eq 1
            end
          end

          context 'when saving the last operation to the database fails' do
            before do
              allow_any_instance_of(VCAP::CloudController::ManagedServiceInstance).
                to receive(:save_and_update_operation).and_raise(Sequel::Error.new('foo'))
            end

            it 'should continue' do
              Timecop.travel(job.polling_interval_seconds + 1.second)
              execute_all_jobs(expected_successes: 1, expected_failures: 0)

              expect(Delayed::Job.count).to eq 1
            end
          end
        end

        context 'when saving the last operation to the database fails' do
          before do
            allow_any_instance_of(VCAP::CloudController::ManagedServiceInstance).
              to receive(:save_and_update_operation).and_raise(Sequel::Error.new('foo'))
          end

          it 'should continue' do
            Timecop.travel(job.polling_interval_seconds + 1.second)
            execute_all_jobs(expected_successes: 1, expected_failures: 0)

            expect(Delayed::Job.count).to eq 1
          end
        end
      end

      context 'timing out' do
        it 'marks the service instance update as failed' do
          Timecop.freeze(Time.now + job.maximum_duration_seconds + 1) do
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            service_instance.reload

            expect(service_instance.last_operation.type).to eq(operation_type)
            expect(service_instance.last_operation.state).to eq('failed')
            expect(service_instance.last_operation.description).to eq("Service Broker failed to #{operation_type_client_method} within the required time.")
          end
        end

        context 'when the plan has a maximum duration' do
          let(:maximum_polling_duration) { 4242 }

          it 'uses it' do
            Timecop.freeze(Time.now + 4243) do
              execute_all_jobs(expected_successes: 0, expected_failures: 1)

              service_instance.reload

              expect(service_instance.last_operation.type).to eq(operation_type)
              expect(service_instance.last_operation.state).to eq('failed')
              expect(service_instance.last_operation.description).to eq("Service Broker failed to #{operation_type_client_method} within the required time.")
            end
          end
        end
      end
    end

    context 'when action has succeeded' do
      let(:succeeded_last_operation) { { last_operation: { state: 'succeeded', description: '789' } } }

      before do
        Timecop.travel(job.polling_interval_seconds + 1.second)
        allow(client).to receive(:fetch_service_instance_last_operation).and_return(succeeded_last_operation)
        execute_all_jobs(expected_successes: 1, expected_failures: 0)
      end

      it 'updates the database' do
        if operation_type == 'delete'
          expect(VCAP::CloudController::ServiceInstance.first(guid: service_instance.guid)).to be_nil
        else
          expect(service_instance.last_operation.type).to eq(operation_type)
          expect(service_instance.last_operation.state).to eq('succeeded')
          expect(service_instance.last_operation.description).to eq('789')
        end
      end

      it 'completes the job' do
        pollable_job = VCAP::CloudController::PollableJobModel.last
        expect(pollable_job.resource_guid).to eq(service_instance.guid)
        expect(pollable_job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
      end

      it 'creates an audit event' do
        event = VCAP::CloudController::Event.find(type: "audit.service_instance.#{operation_type}")
        expect(event).to be
        expect(event.actee).to eq(service_instance.guid)
      end
    end

    context 'when action has failed' do
      let(:failed_last_operation) { { last_operation: { state: 'failed', description: 'oops' } } }

      before do
        Timecop.travel(job.polling_interval_seconds + 1.second)
        allow(client).to receive(:fetch_service_instance_last_operation).and_return(failed_last_operation)
        execute_all_jobs(expected_successes: 0, expected_failures: 1)
      end

      it 'updates the service_instance with last operation' do
        service_instance.reload
        expect(service_instance.last_operation.type).to eq(operation_type)
        expect(service_instance.last_operation.state).to eq('failed')
        expect(service_instance.last_operation.description).to eq('oops')
      end

      it 'updates the job with the api error' do
        pollable_job = VCAP::CloudController::PollableJobModel.last
        expect(pollable_job.resource_guid).to eq(service_instance.guid)
        expect(pollable_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
        expect(pollable_job.cf_api_error).not_to be_nil
        error = YAML.safe_load(pollable_job.cf_api_error)
        expect(error['errors'].first['code']).to eq(api_error_code)
        expect(error['errors'].first['detail']).
          to include('oops')
      end

      it 'does not create an audit event' do
        event = VCAP::CloudController::Event.find(type: "audit.service_instance.#{operation_type}")
        expect(event).to be_nil
      end
    end
  end
end

RSpec.shared_examples 'a one-off service instance job' do
  let(:broker_client_response) {
    { last_operation: { type: 'delete', state: 'succeeded' } }
  }

  context 'when the broker responds with success' do
    before do
      allow(client).to receive(operation).and_return(broker_client_response)
      run_job(job, jobs_succeeded: 1)
    end

    it 'asks the client to execute the operation on the service instance' do
      expect(client).to have_received(operation).with(
        service_instance,
        accepts_incomplete: true,
      )
    end

    it 'completes the job' do
      pollable_job = VCAP::CloudController::PollableJobModel.last
      expect(pollable_job.resource_guid).to eq(service_instance.guid)
      expect(pollable_job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
    end

    it 'creates an audit event' do
      event = VCAP::CloudController::Event.find(type: "audit.service_instance.#{operation_type}")
      expect(event).to be
      expect(event.actee).to eq(service_instance.guid)
    end

    it 'updates the database accordingly' do
      db_checks.call
    end
  end

  context 'when the broker client raises' do
    before do
      allow(client).to receive(operation).and_raise('Oh no')
    end

    it 'updates the instance status to delete failed' do
      run_job(job, jobs_succeeded: 0, jobs_failed: 1)

      service_instance.reload

      expect(service_instance.operation_in_progress?).to eq(false)
      expect(service_instance.terminal_state?).to eq(true)
      expect(service_instance.last_operation.type).to eq(operation_type)
      expect(service_instance.last_operation.state).to eq('failed')
    end

    it 'fails the pollable job' do
      pollable_job = run_job(job, jobs_succeeded: 0, jobs_failed: 1)
      pollable_job.reload
      expect(pollable_job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
    end
  end
end
