RSpec.shared_examples 'create binding orphan mitigation' do
  let(:job) { VCAP::CloudController::PollableJobModel.last }

  before do
    stub_request(:delete, bind_url).
      with(query: {
        accepts_incomplete: true,
        plan_id: plan_id,
        service_id: offering_id,
      }).to_return(status: 200, body: {}.to_json)
  end

  context 'broker returns a success code' do
    codes = [200, 201]
    codes.each do |code|
      context "response is #{code}" do
        before do
          stub_request(:put, bind_url).
            with(query: {
              accepts_incomplete: true,
            },
              body: client_body).to_return(status: code, body: {}.to_json)
        end

        it 'updates the binding and job' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq('succeeded')

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)

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

    context 'response is 201 with malformed response' do
      before do
        stub_request(:put, bind_url).
          with(query: {
            accepts_incomplete: true,
          },
            body: client_body).to_return(status: 201, body: nil)
      end

      it 'updates the binding and performs orphan mitigation' do
        execute_all_jobs(expected_successes: 1, expected_failures: 1)

        assert_failed_job(binding, job)
        assert_orphan_mitigation_performed(plan_id, offering_id)
      end
    end
  end

  context 'broker does not process the request' do
    [400, 401, 408, 409, *411..431].each do |code|
      context "response is #{code}" do
        before do
          stub_request(:put, bind_url).
            with(query: {
              accepts_incomplete: true,
            },
              body: client_body).to_return(status: code, body: { error: 'ConcurrencyError', description: 'some description' }.to_json)
        end

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

  context 'broker fails to bind with an error not specified in osbapi' do
    [*500..511, *203..208].sample(4).each do |code|
      context "response is #{code}" do
        before do
          stub_request(:put, bind_url).
            with(query: {
              accepts_incomplete: true,
            },
              body: client_body).to_return(status: code, body: {}.to_json)
        end

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

      stub_request(:delete, bind_url).
        with(query: {
          accepts_incomplete: true,
          plan_id: plan_id,
          service_id: offering_id,
        }).to_return(status: 200, body: {}.to_json)
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
  expect(
    a_request(:delete, bind_url).
      with(
        query: {
          accepts_incomplete: true,
          plan_id: plan_id,
          service_id: offering_id,
        },
      )
  ).to have_been_made.once
end
