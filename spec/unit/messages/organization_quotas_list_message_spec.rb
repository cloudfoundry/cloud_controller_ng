require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationQuotasListMessage do
    describe '.from_params' do
      let(:params) do
        {
          'page' => 1,
          'per_page' => 5,
          'guids' => 'org-quota1-guid,org-quota2-guid',
          'names' => 'org-quota1-name,org-quota2-name',
          'organization_guids' => 'org1-guid,org2-guid'
        }
      end

      it 'returns the correct OrganizationQuotasListMessage' do
        message = OrganizationQuotasListMessage.from_params(params)

        expect(message).to be_a(OrganizationQuotasListMessage)
        expect(message.page).to eq(1)
        expect(message.per_page).to eq(5)
        expect(message.guids).to eq(%w[org-quota1-guid org-quota2-guid])
        expect(message.names).to eq(%w[org-quota1-name org-quota2-name])
        expect(message.organization_guids).to eq(%w[org1-guid org2-guid])
      end

      it 'converts requested keys to symbols' do
        message = OrganizationQuotasListMessage.from_params(params)

        expect(message).to be_requested(:page)
        expect(message).to be_requested(:per_page)
        expect(message).to be_requested(:guids)
        expect(message).to be_requested(:names)
        expect(message).to be_requested(:organization_guids)
      end

      context 'guids, names, organization_guids are nil' do
        let(:params) do
          {
            guids: nil,
            names: nil,
            organization_guids: nil
          }
        end

        it 'is valid' do
          message = OrganizationQuotasListMessage.from_params(params)
          expect(message).to be_valid
        end
      end

      context 'guids, names, organization_guids must be arrays' do
        let(:params) do
          {
            guids: 'a',
            names: { 'not' => 'an array' },
            organization_guids: 3.14159
          }
        end

        it 'is invalid' do
          message = OrganizationQuotasListMessage.from_params(params)
          expect(message).not_to be_valid
          expect(message.errors_on(:guids)).to include('must be an array')
          expect(message.errors_on(:names)).to include('must be an array')
          expect(message.errors_on(:organization_guids)).to include('must be an array')
        end
      end

      context 'when there are additional keys' do
        let(:params) do
          {
            'page' => 1,
            'per_page' => 5,
            'foobar' => 'pants'
          }
        end

        it 'fails to validate' do
          message = OrganizationQuotasListMessage.from_params(params)

          expect(message).not_to be_valid
        end
      end
    end
  end
end
