require 'spec_helper'
require 'presenters/v3/organization_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe OrganizationPresenter do
    let(:organization_quota) do
      VCAP::CloudController::QuotaDefinition.make(guid: 'quota-guid')
    end
    let(:organization) do
      VCAP::CloudController::Organization.make(quota_definition: organization_quota)
    end
    let!(:release_label) do
      VCAP::CloudController::OrganizationLabelModel.make(
        key_name: 'release',
        value: 'stable',
        resource_guid: organization.guid
      )
    end

    let!(:potato_label) do
      VCAP::CloudController::OrganizationLabelModel.make(
        key_prefix: 'maine.gov',
        key_name: 'potato',
        value: 'mashed',
        resource_guid: organization.guid
      )
    end

    let!(:organization_annotation_the_first) do
      VCAP::CloudController::OrganizationAnnotationModel.make(
        key: 'city',
        value: 'Monticello',
        resource_guid: organization.guid
      )
    end
    let!(:organization_annotation_the_second) do
      VCAP::CloudController::OrganizationAnnotationModel.make(
        key: 'state',
        value: 'Indiana',
        resource_guid: organization.guid
      )
    end

    describe '#to_hash' do
      let(:result) { OrganizationPresenter.new(organization).to_hash }

      it 'presents the org as json' do
        expect(result[:guid]).to eq(organization.guid)
        expect(result[:created_at]).to eq(organization.created_at)
        expect(result[:updated_at]).to eq(organization.updated_at)
        expect(result[:name]).to eq(organization.name)
        expect(result[:suspended]).to eq(false)
        expect(result[:links][:self][:href]).to match(%r{/v3/organizations/#{organization.guid}$})
        expect(result[:links][:domains][:href]).to match(%r{/v3/organizations/#{organization.guid}/domains$})
        expect(result[:links][:default_domain][:href]).to match(%r{/v3/organizations/#{organization.guid}/domains/default$})
        expect(result[:links][:quota][:href]).to match(%r{/v3/organization_quotas/#{organization_quota.guid}$})
        expect(result[:metadata][:labels]).to eq('release' => 'stable', 'maine.gov/potato' => 'mashed')
        expect(result[:metadata][:annotations]).to eq('city' => 'Monticello', 'state' => 'Indiana')
        expect(result[:relationships][:quota][:data][:guid]).to eq('quota-guid')
      end
    end
  end
end
