RSpec.shared_examples 'create binding orphan mitigation' do
  let(:job) { VCAP::CloudController::PollableJobModel.last }
  let(:bind_response_body) { '{}' }
  let(:broker_bind_status_code) { 200 }

  before do
    stub_request(:delete, bind_url).
      with(query: {
        accepts_incomplete: true,
        plan_id: plan_id,
        service_id: offering_id,
      }).to_return(status: 200, body: {}.to_json)

    stub_request(:put, bind_url).
      with(query: { accepts_incomplete: true }).to_return(status: broker_bind_status_code, body: bind_response_body)
  end

  after do
    WebMock.reset!
  end

  context 'should not be performed' do
    context 'broker returns valid 200, 201, 202' do
      before do
        stub_request(:get, "#{bind_url}/last_operation").
          with({ query: { plan_id: plan_id, service_id: offering_id } }).
          to_return(status: 200, body: '{}')
      end

      [200, 201, 202].each do |code|
        context "response is #{code}" do
          let(:broker_bind_status_code) { code }

          it 'succeeds the job and does not perform orphan mitigation' do
            execute_all_jobs(expected_successes: 1, expected_failures: 0)
            assert_no_orphan_mitigation_performed(plan_id, offering_id)
          end
        end
      end
    end

    context 'response is 200 with malformed response' do
      let(:broker_bind_status_code) { 200 }
      let(:bind_response_body) { nil }

      it 'fails the job and does not perform orphan mitigation' do
        execute_all_jobs(expected_successes: 0, expected_failures: 1)

        assert_failed_job(binding, job)
        assert_no_orphan_mitigation_performed(plan_id, offering_id)
      end
    end

    context 'response is 422 with known reason' do
      let(:broker_bind_status_code) { 422 }
      let(:bind_response_body) { '{ "error": "ConcurrencyError", "description": "some description" }' }

      it 'fails the job and does not perform orphan mitigation' do
        execute_all_jobs(expected_successes: 0, expected_failures: 1)

        assert_failed_job(binding, job)
        assert_no_orphan_mitigation_performed(plan_id, offering_id)
      end
    end

    context 'broker returns a 4xx code' do
      [400, 401, 408, 409, *411..421, *423..431].each do |code|
        context "response is #{code}" do
          let(:broker_bind_status_code) { code }
          let(:bind_response_body) { '{ "error": "some 4xx error", "description": "some description" }' }

          it 'fails the job and updates the binding and job' do
            execute_all_jobs(expected_successes: 0, expected_failures: 1)

            assert_failed_job(binding, job)
            assert_no_orphan_mitigation_performed(plan_id, offering_id)
          end
        end
      end
    end

    context 'last operation response' do
      context 'response for last operation is 200 state failed' do
        let(:broker_bind_status_code) { 202 }
        before do
          stub_request(:get, "#{bind_url}/last_operation").
            with({ query: { plan_id: plan_id, service_id: offering_id } }).
            to_return(status: 200, body: '{"state": "failed"}')
        end

        it 'fails the job and does not perform orphan mitigation' do
          execute_all_jobs(expected_successes: 0, expected_failures: 1)

          assert_failed_job(binding, job)
          assert_no_orphan_mitigation_performed(plan_id, offering_id)
        end
      end

      context 'response for last operation is 200 with a malformed response' do
        let(:broker_bind_status_code) { 202 }
        before do
          stub_request(:get, "#{bind_url}/last_operation").
            with({ query: { plan_id: plan_id, service_id: offering_id } }).
            to_return(status: 200, body: 'this is not json')
        end

        it 'retries the job and does not perform orphan mitigation' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          assert_polling_job(binding, job)
          assert_no_orphan_mitigation_performed(plan_id, offering_id)
        end
      end

      context 'response for last operation is 410' do
        let(:broker_bind_status_code) { 202 }

        before do
          stub_request(:get, "#{bind_url}/last_operation").
            with({ query: { plan_id: plan_id, service_id: offering_id } }).
            to_return(status: 410, body: '{}')
        end

        it 'retries the job does not perform orphan mitigation' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          assert_polling_job(binding, job)
          assert_no_orphan_mitigation_performed(plan_id, offering_id)
        end
      end

      context 'response for last operation is 404' do
        let(:broker_bind_status_code) { 202 }
        before do
          stub_request(:get, "#{bind_url}/last_operation").
            with({ query: { plan_id: plan_id, service_id: offering_id } }).
            to_return(status: 404, body: '{}')
        end

        it 'retries and does not perform orphan mitigation' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          assert_polling_job(binding, job)
          assert_no_orphan_mitigation_performed(plan_id, offering_id)
        end
      end

      context 'response for last operation is 400' do
        let(:broker_bind_status_code) { 202 }
        before do
          stub_request(:get, "#{bind_url}/last_operation").
            with({ query: { plan_id: plan_id, service_id: offering_id } }).
            to_return(status: 400, body: '{}')
        end

        it 'fails the job and does not perform orphan mitigation' do
          execute_all_jobs(expected_successes: 0, expected_failures: 1)

          assert_failed_job(binding, job)
          assert_no_orphan_mitigation_performed(plan_id, offering_id)
        end
      end
    end
  end

  context 'should be performed' do
    context 'broker returns 200 with bad data' do
      let(:broker_bind_status_code) { 200 }
      let(:bind_response_body) { '{ "route_service_url": "bad-url"}' }

      it 'fails the job and performs OM' do
        execute_all_jobs(expected_successes: 1, expected_failures: 1)

        assert_failed_job(binding, job)
        assert_orphan_mitigation_performed(plan_id, offering_id)
      end
    end

    context 'broker returns a 2xx code' do
      [201, 202].each do |code|
        context "response is #{code} with malformed response" do
          let(:broker_bind_status_code) { code }
          let(:bind_response_body) { nil }

          it 'performs orphan mitigation' do
            execute_all_jobs(expected_successes: 1, expected_failures: 1)

            assert_failed_job(binding, job)
            assert_orphan_mitigation_performed(plan_id, offering_id)
          end
        end
      end

      [203, 204, 205, 206, 206, 208, 226].each do |code|
        context "broker response is #{code}" do
          let(:broker_bind_status_code) { code }
          let(:bind_response_body) { '{}' }

          it 'performs orphan mitigation' do
            execute_all_jobs(expected_successes: 1, expected_failures: 1)
            assert_orphan_mitigation_performed(plan_id, offering_id)
          end
        end
      end
    end

    context 'broker returns a 410 code' do
      let(:broker_bind_status_code) { 410 }

      it 'does orphan mitigation and fails the job' do
        execute_all_jobs(expected_successes: 1, expected_failures: 1)

        assert_failed_job(binding, job)
        assert_orphan_mitigation_performed(plan_id, offering_id)
      end
    end

    context 'broker response is 422 with unknown reason' do
      let(:broker_bind_status_code) { 422 }
      let(:bind_response_body) { '{ "error": "some random unprocessable entity", "description": "some description" }' }

      it 'fails the job and performs orphan mitigation' do
        execute_all_jobs(expected_successes: 1, expected_failures: 1)

        assert_failed_job(binding, job)
        assert_orphan_mitigation_performed(plan_id, offering_id)
      end
    end

    context 'broker returns a 5xx code' do
      Array(500..511).each do |code|
        context "response is #{code}" do
          let(:broker_bind_status_code) { code }

          it 'does orphan mitigation and fails the job' do
            execute_all_jobs(expected_successes: 1, expected_failures: 1)

            assert_failed_job(binding, job)
            assert_orphan_mitigation_performed(plan_id, offering_id)
          end
        end
      end
    end

    context 'timeout' do
      before do
        stub_request(:put, bind_url).
          with(query: {
            accepts_incomplete: true,
          }).to_timeout
      end

      it 'does orphan mitigation and fails the job' do
        execute_all_jobs(expected_successes: 1, expected_failures: 1)

        assert_failed_job(binding, job)
        assert_orphan_mitigation_performed(plan_id, offering_id)
      end
    end
  end
end

def assert_failed_job(binding, job)
  binding.reload
  expect(binding.last_operation.type).to eq('create')
  expect(binding.last_operation.state).to eq('failed')
  expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
end

def assert_polling_job(binding, job)
  binding.reload
  expect(binding.last_operation.type).to eq('create')
  expect(binding.last_operation.state).to eq('in progress')
  expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
end

def assert_orphan_mitigation_performed(plan_id, offering_id)
  expect(delete_request(plan_id, offering_id)).to have_been_made.once
end

def assert_no_orphan_mitigation_performed(plan_id, offering_id)
  expect(delete_request(plan_id, offering_id)).to_not have_been_made
end

def delete_request(plan_id, offering_id)
  a_request(:delete, bind_url).
    with(
      query: {
        accepts_incomplete: true,
        plan_id: plan_id,
        service_id: offering_id,
      }
    )
end
