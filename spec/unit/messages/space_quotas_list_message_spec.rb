require 'spec_helper'
require 'messages/space_quotas_list_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotasListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
        }
      end

      it 'returns the correct SpaceQuotasListMessage' do
        message = SpaceQuotasListMessage.from_params(params)

        expect(message).to be_a(SpaceQuotasListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
      end

      it 'converts requested keys to symbols' do
        message = SpaceQuotasListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
      end

      context 'when there are additional keys' do
        let(:params) do
          {
            'page' => 1,
            'per_page' => 5,
            'foobar' => 'pants',
          }
        end

        it 'fails to validate' do
          message = SpaceQuotasListMessage.from_params(params)

          expect(message).to be_invalid
        end
      end
    end
  end
end
