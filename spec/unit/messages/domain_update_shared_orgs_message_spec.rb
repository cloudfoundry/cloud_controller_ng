require 'spec_helper'
require 'messages/domain_update_shared_orgs_message'

module VCAP::CloudController
  RSpec.describe DomainUpdateSharedOrgsMessage do
    subject { DomainUpdateSharedOrgsMessage.new(params) }

    describe 'validations' do
      context 'when valid params are given' do
        let(:params) { { guid: 'domain-guid', data: [{ guid: 'org-guid1' }, { guid: 'org-guid2' }] } }

        it 'is valid' do
          expect(subject).to be_valid
        end

        its(:guid) { should eq('domain-guid') }
        its(:shared_organizations_guids) { should eq(%w[org-guid1 org-guid2]) }
      end

      context 'when no params are given' do
        let(:params) {}
        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:base]).to include('Data must have the structure "data": [{"guid": shared_org_guid_1}, {"guid": shared_org_guid_2}]')
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            unexpected: 'meow',
          }
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when invalid params are given' do
        context 'data is not an array' do
          let(:params) { { data: 1 } }

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:base]).to include('Data must have the structure "data": [{"guid": shared_org_guid_1}, {"guid": shared_org_guid_2}]')
          end
        end
        context 'data has invalid array elements' do
          let(:params) { { data: [{ guid: 1 }, { bad_guid: true }] } }
          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:base]).to include('Data must have the structure "data": [{"guid": shared_org_guid_1}, {"guid": shared_org_guid_2}]')
          end
        end
        context 'data is not an array of hashes' do
          let(:params) { { data: [1, 2, 3] } }
          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:base]).to include('Data must have the structure "data": [{"guid": shared_org_guid_1}, {"guid": shared_org_guid_2}]')
          end
        end
      end
    end
  end
end
