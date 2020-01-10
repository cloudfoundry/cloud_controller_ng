require 'spec_helper'
require 'fetchers/organization_quota_list_fetcher'
require 'messages/organization_quotas_list_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotaListFetcher do
    let(:default_quota) { VCAP::CloudController::QuotaDefinition.default }
    let!(:quota1) { QuotaDefinition.make(name: 'Mercury', guid: 'quota1-guid') }
    let!(:quota2) { QuotaDefinition.make(name: 'Venus', guid: 'quota2-guid') }
    let!(:quota3) { QuotaDefinition.make(name: 'Jupiter', guid: 'quota3-guid') }

    let(:org1) { Organization.make(name: 'org1', quota_definition: quota1) }
    let(:org3) { Organization.make(name: 'org2', quota_definition: quota3) }
    let(:visible_orgs) { [org1.guid, org3.guid] }

    let(:message) { OrganizationQuotasListMessage.from_params(filters) }

    subject { OrganizationQuotaListFetcher.fetch(message: message, readable_org_guids: visible_orgs).all }

    describe '#fetch' do
      context 'when filters are not provided' do
        let(:filters) { {} }

        it 'fetches all the quotas' do
          expect(subject).to match_array([quota1, quota2, quota3, default_quota])
        end
      end

      context 'when names filter is given' do
        let(:filters) { { 'names' => 'Mercury,Venus' } }

        it 'includes the quotas with the provided guids and matching the filter' do
          expect(subject).to match_array([quota1, quota2])
        end
      end

      context 'when guids filter is given' do
        let(:filters) { { 'guids' => "#{quota2.guid},#{quota3.guid}" } }

        it 'includes the quotas with the provided guids and matching the filter' do
          expect(subject).to match_array([quota2, quota3])
        end
      end

      context 'when organization guids filter is given' do
        let(:filters) { { 'organization_guids' => "#{org1.guid},#{org3.guid}" } }

        it 'includes the quotas with the provided guids and matching the filter' do
          expect(subject).to match_array([quota1, quota3])
        end

        context 'and the org guid filter is out of scope' do
          let(:visible_orgs) { [] }

          it 'includes the quotas with the provided guids and matching the filter' do
            expect(subject).to match_array([])
          end
        end
      end
    end
  end
end
