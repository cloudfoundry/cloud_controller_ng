require 'spec_helper'
require 'presenters/v3/organization_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe OrganizationPresenter do
    let(:organization) { VCAP::CloudController::Organization.make }

    describe '#to_hash' do
      let(:result) { OrganizationPresenter.new(organization).to_hash }

      it 'presents the org as json' do
        expect(result[:guid]).to eq(organization.guid)
        expect(result[:created_at]).to eq(organization.created_at)
        expect(result[:updated_at]).to eq(organization.updated_at)
        expect(result[:name]).to eq(organization.name)
        expect(result[:links][:self][:href]).to match(%r{/v3/organizations/#{organization.guid}$})
      end
    end
  end
end
