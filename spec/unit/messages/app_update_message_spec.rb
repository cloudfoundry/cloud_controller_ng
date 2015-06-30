require 'spec_helper'
require 'messages/app_update_message'

module VCAP::CloudController
  describe AppUpdateMessage do
    describe '.create_from_http_request' do
      let(:body) {
        {
          'name' => 'some-name',
          'buildpack' => 'some-buildpack',
          'environment_variables' => {
            'ENVVAR' => 'env-val'
          }
        }
      }

      it 'returns the correct AppUpdateMessage' do
        message = AppUpdateMessage.create_from_http_request(body)

        expect(message).to be_a(AppUpdateMessage)
        expect(message.name).to eq('some-name')
        expect(message.buildpack).to eq('some-buildpack')
        expect(message.environment_variables).to eq({ 'ENVVAR' => 'env-val' })
      end

      it 'converts requested keys to symbols' do
        message = AppUpdateMessage.create_from_http_request(body)

        expect(message.requested?(:name)).to be_truthy
        expect(message.requested?(:buildpack)).to be_truthy
        expect(message.requested?(:environment_variables)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:base]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when name is not a string' do
        let(:params) { { name: 32.77 } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:name)).to include('must be a string')
        end
      end

      context 'when environment_variables is not a hash' do
        let(:params) { { environment_variables: 'potato' } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:environment_variables)[0]).to include('must be a hash')
        end
      end

      context 'when a buildpack is not a string' do
        let(:params) { { buildpack: 45 } }

        it 'is not valid' do
          message = AppUpdateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:buildpack)).to include('must be a string')
        end
      end
    end
  end
end
