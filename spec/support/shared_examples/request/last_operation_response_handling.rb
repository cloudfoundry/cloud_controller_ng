RSpec.shared_examples 'last operation response handling' do
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

          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq('failed')
          expect(binding.last_operation.description).to eq(response[:body][:description])

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::COMPLETE_STATE)
        end
      end
    end
  end

  context 'invalid http codes' do
    [404, 410, 500].each do |code|
      context "last operation response is #{code}" do
        let(:last_operation_status_code) { code }
        let(:last_operation_body) { 'something awful' }

        it 'continues polling' do
          execute_all_jobs(expected_successes: 1, expected_failures: 0)

          expect(binding.last_operation.type).to eq('create')
          expect(binding.last_operation.state).to eq('in progress')
          expect(binding.last_operation.description).to include("Status Code: #{code}") unless code == 410

          expect(job.state).to eq(VCAP::CloudController::PollableJobModel::POLLING_STATE)
        end
      end
    end
  end
end
