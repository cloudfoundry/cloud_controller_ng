require 'spec_helper'
require 'messages/space_quotas_list_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotasListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'guids' => 'org-quota1-guid,org-quota2-guid',
          'names' => 'org-quota1-name,org-quota2-name',
          'organization_guids' => 'org1-guid,org2-guid',
          'space_guids' => 'space1-guid,space2-guid',
        }
      end

      it 'returns the correct SpaceQuotasListMessage' do
        message = SpaceQuotasListMessage.from_params(params)

        expect(message).to be_a(SpaceQuotasListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.guids).to eq(%w[org-quota1-guid org-quota2-guid])
        expect(message.names).to eq(%w[org-quota1-name org-quota2-name])
        expect(message.organization_guids).to eq(%w[org1-guid org2-guid])
        expect(message.space_guids).to eq(%w[space1-guid space2-guid])
      end

      it 'converts requested keys to symbols' do
        message = SpaceQuotasListMessage.from_params(params)

        expect(message.requested?(:page)).to be_truthy
        expect(message.requested?(:per_page)).to be_truthy
        expect(message.requested?(:guids)).to be_truthy
        expect(message.requested?(:names)).to be_truthy
        expect(message.requested?(:organization_guids)).to be_truthy
        expect(message.requested?(:space_guids)).to be_truthy
      end

      context 'guids, names, organization_guids, space_guids are nil' do
        let(:params) do
          {
            guids: nil,
            names: nil,
            organization_guids: nil,
            space_guids: nil,
          }
        end

        it 'is valid' do
          message = SpaceQuotasListMessage.from_params(params)
          expect(message).to be_valid
        end
      end

      context 'guids, names, organization_guids, space_guids must be arrays' do
        let(:params) do
          {
            guids: 'a',
            names: { 'not' => 'an array' },
            organization_guids: 3.14159,
            space_guids: false,
          }
        end

        it 'is invalid' do
          message = SpaceQuotasListMessage.from_params(params)
          expect(message).to be_invalid
          expect(message.errors.details[:guids].first[:error]).to eq('must be an array')
          expect(message.errors.details[:names].first[:error]).to eq('must be an array')
          expect(message.errors.details[:organization_guids].first[:error]).to eq('must be an array')
          expect(message.errors.details[:space_guids].first[:error]).to eq('must be an array')
        end
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
