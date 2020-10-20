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
      with(query: { accepts_incomplete: true },
        body: client_body).to_return(status: broker_bind_status_code, body: bind_response_body)
  end

  context 'when it is not performed' do
    before do
      stub_request(:get, "#{bind_url}/last_operation").
        with({ query: { plan_id: plan_id, service_id: offering_id } }).
        to_return(status: 200, body: '{"state": "in progress"}')
    end

    [200, 201, 202].each do |code|
      context "response is #{code}" do
        let(:broker_bind_status_code) { code }

        it 'does not perform orphan mitigation' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)
          assert_no_orphan_mitigation_performed(plan_id, offering_id)
        end
      end
    end

    context 'response is 200 with malformed response' do
      let(:broker_bind_status_code) { 200 }
      let(:bind_response_body) { nil }

      it 'does not perform orphan mitigation' do
        execute_all_jobs(expected_successes: 0, expected_failures: 1)

        assert_failed_job(binding, job)
        assert_no_orphan_mitigation_performed(plan_id, offering_id)
      end
    end

    context 'response for last operation is 200 state failed' do
      let(:broker_bind_status_code) { 202 }
      before do
        stub_request(:get, "#{bind_url}/last_operation").
          with({ query: { plan_id: plan_id, service_id: offering_id } }).
          to_return(status: 200, body: '{"state": "failed"}')
      end

      it 'does not perform orphan mitigation' do
        execute_all_jobs(expected_successes: 0, expected_failures: 1)
        assert_no_orphan_mitigation_performed(plan_id, offering_id)
      end
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
      context "response is #{code}" do
        let(:broker_bind_status_code) { code }
        let(:bind_response_body) { '{}' }

        it 'performs orphan mitigation' do
          execute_all_jobs(expected_successes: 1, expected_failures: 1)
          assert_orphan_mitigation_performed(plan_id, offering_id)
        end
      end
    end
  end

  context 'broker returns a 4xx code' do
    [400, 401, 408, 409, *411..431].each do |code|
      context "response is #{code}" do
        let(:broker_bind_status_code) { code }
        let(:bind_response_body) { '{ "error": "ConcurrencyError", "description": "some description" }' }

        it 'updates the binding and job' do
          execute_all_jobs(expected_successes: 0, expected_failures: 1)

          assert_failed_job(binding, job)

          expect(
            a_request(:delete, bind_url).
              with(
                query: {
                  accepts_incomplete: true,
                  plan_id: plan_id,
                  service_id: offering_id,
                },
              )
          ).not_to have_been_made
        end
      end
    end
  end

  context 'broker returns a 5xx code' do
    [*500..511].each do |code|
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
        },
          body: client_body).to_timeout
    end

    it 'does orphan mitigation and fails the job' do
      execute_all_jobs(expected_successes: 1, expected_failures: 1)

      assert_failed_job(binding, job)
      assert_orphan_mitigation_performed(plan_id, offering_id)
    end
  end
end

def assert_failed_job(binding, job)
  binding.reload
  expect(binding.last_operation.type).to eq('create')
  expect(binding.last_operation.state).to eq('failed')
  expect(job.state).to eq(VCAP::CloudController::PollableJobModel::FAILED_STATE)
end

def assert_orphan_mitigation_performed(plan_id, offering_id)
  expect(delete_request(plan_id, offering_id)).to have_been_made.once
end

def assert_no_orphan_mitigation_performed(plan_id, offering_id)
  expect(delete_request(plan_id, offering_id)).to_not have_been_made.once
end

def delete_request(plan_id, offering_id)
  a_request(:delete, bind_url).
    with(
      query: {
        accepts_incomplete: true,
        plan_id: plan_id,
        service_id: offering_id,
      },
    )
end
