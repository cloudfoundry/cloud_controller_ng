require 'spec_helper'
require 'cloud_controller/diego/staging_response'

module VCAP::CloudController::Diego
  describe StagingResponse do
    let(:detected_start_command) do
      { web: 'start_command', background: 'background_command' }
    end

    let(:lifecycle_data) { { foo: 'bar' } }

    let(:success_response) do
      {
        execution_metadata: 'some metadata',
        detected_start_command: detected_start_command,
        lifecycle_data: lifecycle_data,
      }
    end

    let(:error_payload) do
      {
        error: {
          id: 'StagingError',
          message: 'error message details',
        }
      }
    end

    let(:payload) { success_response }
    let(:response) { StagingResponse.new(payload) }

    describe 'execution_metadata' do
      it 'returns the execution metadata' do
        expect(response.execution_metadata).to eq('some metadata')
      end
    end

    describe 'detected_start_command' do
      it 'returns the detected_start_command hash' do
        expect(response.detected_start_command).to eq(detected_start_command)
      end
    end

    describe 'lifecycle_data' do
      it 'returns the lifecycle data hash' do
        expect(response.lifecycle_data).to eq(lifecycle_data)
      end
    end

    describe 'error?' do
      context 'when the response contains error' do
        let(:payload) { error_payload }

        it 'returns true' do
          expect(response.error?).to be_truthy
        end
      end

      context 'when the response does not contain an error' do
        it 'returns false' do
          expect(response.error?).to be_falsey
        end
      end
    end

    describe 'error_id' do
      context 'when the payload contains an error' do
        let(:payload) { error_payload }

        it 'returns the error id' do
          expect(response.error_id).to eq(error_payload[:error][:id])
        end
      end

      context 'when the payload does not contain an error' do
        it 'returns nil' do
          expect(response.error_id).to be_nil
        end
      end
    end

    describe 'error_message' do
      context 'when the payload contains an error' do
        let(:payload) { error_payload }

        it 'returns the error id' do
          expect(response.error_message).to eq(error_payload[:error][:message])
        end
      end

      context 'when the payload does not contain an error' do
        it 'returns nil' do
          expect(response.error_id).to be_nil
        end
      end
    end

    describe 'validation' do
      context 'when the payload is not a hash' do
        it 'raises an api error' do
          expect {
            StagingResponse.new('whatever')
          }.to raise_error(VCAP::Errors::ApiError)
        end
      end

      context 'when the payload is missing a required key' do
        let(:malformed_response) { success_response.except(:execution_metadata) }

        it 'raises an api error' do
          expect {
            StagingResponse.new(malformed_response)
          }.to raise_error(VCAP::Errors::ApiError)
        end
      end

      context 'when detected_start_command is missing the web key' do
        let(:detected_start_command) do
          { background: 'background_command' }
        end

        it 'raises an api error' do
          expect {
            StagingResponse.new(payload)
          }.to raise_error(VCAP::Errors::ApiError)
        end
      end
    end
  end
end
