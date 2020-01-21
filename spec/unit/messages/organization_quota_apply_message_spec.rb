require 'spec_helper'
require 'messages/organization_quota_apply_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaApplyMessage do
    subject { OrganizationQuotaApplyMessage.new(params) }

    let(:params) do
      {
        data: [{ guid: 'org-guid-1' }, { guid: 'org-guid-2' }]
      }
    end

    describe '#organization_guids' do
      it 'returns the org guids' do
        expect(subject.organization_guids).to eq(%w(org-guid-1 org-guid-2))
      end
    end

    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:data]).to eq ["can't be blank", 'must be an array']
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'meow', name: 'the-name' } }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when data is malformed' do
        let(:params) { { data: 'wat' } }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include('Data must be an array')
        end
      end
    end
  end
end
