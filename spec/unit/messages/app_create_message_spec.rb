require 'spec_helper'
require 'messages/app_create_message'

module VCAP::CloudController
  describe AppCreateMessage do
    describe '.create_from_http_request' do
      let(:body) { { 'name' => 'some-name', 'space_guid' => 'some-guid', 'environment_variables' => { 'ENVVAR' => 'env-val' } } }

      it 'returns the correct AppCreateMessage' do
        message = AppCreateMessage.create_from_http_request(body)

        expect(message).to be_a(AppCreateMessage)
        expect(message.name).to eq('some-name')
        expect(message.space_guid).to eq('some-guid')
        expect(message.environment_variables).to eq({ 'ENVVAR' => 'env-val' })
      end

      it 'converts requested keys to symbols' do
        message = AppCreateMessage.create_from_http_request(body)

        expect(message.requested?(:name)).to be_truthy
        expect(message.requested?(:space_guid)).to be_truthy
        expect(message.requested?(:environment_variables)).to be_truthy
      end
    end

    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'foo' } }

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when name is not a string' do
        let(:params) { { name: 32.77 } }

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('must be a string')
        end
      end

      context 'when space_guid is not a guid' do
        let(:params) { { name: 'name', space_guid: 34 } }

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:space_guid)).not_to be_empty
        end
      end

      context 'when environment_variables is not a hash' do
        let(:params) { { name: 'name', space_guid: 'guid', environment_variables: 'potato' } }

        it 'is not valid' do
          message = AppCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors_on(:environment_variables)[0]).to include('must be a hash')
        end
      end
    end
  end
end
