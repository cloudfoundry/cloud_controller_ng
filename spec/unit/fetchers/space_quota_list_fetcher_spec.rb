require 'spec_helper'
require 'fetchers/space_quota_list_fetcher'
require 'messages/space_quotas_list_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotaListFetcher do
    let(:org1) { create(:organization, name: 'org1') }
    let(:org3) { create(:organization, name: 'org3') }

    let!(:quota1) { create(:space_quota_definition, name: 'quota1-name', guid: 'quota1-guid', organization: org1) }
    let!(:quota2) { create(:space_quota_definition, name: 'quota2-name', guid: 'quota2-guid', organization: org1) }
    let!(:quota3) { create(:space_quota_definition, name: 'quota3-name', guid: 'quota3-guid', organization: org3) }
    let!(:quota_unreadable) { create(:space_quota_definition, name: 'quota_unreadable-name', guid: 'quota_unreadable-guid', organization: org1) }

    let!(:space1) { create(:space, name: 'space1-name', organization: org1, space_quota_definition: quota1) }
    let!(:space2) { create(:space, name: 'space2-name', organization: org1, space_quota_definition: quota2) }

    let(:readable_space_quota_guids) { [quota1.guid, quota2.guid, quota3.guid] }

    let(:message) { SpaceQuotasListMessage.from_params(filters) }

    subject { SpaceQuotaListFetcher.fetch(message:, readable_space_quota_guids:).all }

    describe '#fetch' do
      context 'when filters are not provided' do
        let(:filters) { {} }

        it 'fetches all the quotas' do
          expect(subject).to contain_exactly(quota1, quota2, quota3)
        end
      end

      context 'when names filter is given' do
        let(:filters) { { 'names' => 'quota1-name,quota2-name' } }

        it 'includes the quotas with the provided guids and matching the filter' do
          expect(subject).to contain_exactly(quota1, quota2)
        end
      end

      context 'when guids filter is given' do
        let(:filters) { { 'guids' => "#{quota2.guid},#{quota3.guid}" } }

        it 'includes the quotas with the provided guids and matching the filter' do
          expect(subject).to contain_exactly(quota2, quota3)
        end
      end

      context 'when organization guids filter is given' do
        let(:filters) { { 'organization_guids' => org1.guid.to_s } }

        it 'includes the quotas with the provided guids and matching the filter' do
          expect(subject).to contain_exactly(quota1, quota2)
        end

        context 'and there are no readable space quotas' do
          let(:readable_space_quota_guids) { [] }

          it 'returns an empty list of quotas' do
            expect(subject).to be_empty
          end
        end
      end

      context 'when space guids filter is given' do
        let(:filters) { { 'space_guids' => "#{space1.guid},#{space2.guid}" } }

        it 'includes the quotas with the provided guids and matching the filter' do
          expect(
            subject.map(&:guid)
          ).to match_array(
            [quota1, quota2].map(&:guid)
          )
        end

        context 'when only a subset of quotas are visible' do
          let(:readable_space_quota_guids) { [quota2.guid] }
          let(:filters) { { 'space_guids' => "#{space1.guid},#{space2.guid}" } }

          it 'does not include the quotas from spaces in orgs that it cannot see' do
            expect(subject).to contain_exactly(quota2)
          end
        end
      end
    end
  end
end
