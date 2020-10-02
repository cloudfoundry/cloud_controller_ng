RSpec.shared_examples 'binding last operation response handling' do |type|
  context 'valid http codes' do
    valid_responses = [
      { code: 400, body: { description: 'helpful message' }, expected_description: 'helpful message' },
      { code: 200, body: { state: 'failed', description: 'something went wrong' }, expected_description: 'something went wrong' }
    ]

    valid_responses.each do |response|
      context "last operation response is #{response[:code]}" do
        let(:state) { response[:state] }
        let(:last_operation_status_code) { response[:code] }
        let(:last_operation_body) { response[:body] }

        it 'updates the binding and job' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          binding.reload
          expect(binding.last_operation.type).to eq(type)
          expect(binding.last_operation.state).to eq('failed')
          expect(binding.last_operation.description).to eq(response[:body][:description])

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
        end
      end
    end
  end

  context 'invalid http codes' do
    [404, 500].each do |code|
      context "last operation response is #{code}" do
        let(:last_operation_status_code) { code }
        let(:last_operation_body) { 'something awful' }

        it 'continues polling' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          binding.reload
          expect(binding.last_operation.type).to eq(type)
          expect(binding.last_operation.state).to eq('in progress')
          expect(binding.last_operation.description).to include("Status Code: #{code}")

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
        end
      end
    end
  end

  context 'timeout' do
    before do
      stub_request(:get, broker_binding_last_operation_url).
        with(query: hash_including({
          operation: operation
        })).to_timeout
    end

    it 'continues polling' do
      execute_all_jobs(expected_successes: 1, expected_failures: 0)

      binding.reload
      expect(binding.last_operation.type).to eq(type)
      expect(binding.last_operation.state).to eq('in progress')

      expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
    end
  end

  context 'connection errors' do
    [SocketError, Errno::ECONNREFUSED, RuntimeError].each do |error|
      before do
        stub_request(:get, broker_binding_last_operation_url).
          with(query: hash_including({
                  operation: operation
                })).to_raise(error)
      end

      it 'continues polling' do
        execute_all_jobs(expected_successes: 1, expected_failures: 0)

        binding.reload
        expect(binding.last_operation.type).to eq(type)
        expect(binding.last_operation.state).to eq('in progress')

        expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
      end
    end
  end
end
