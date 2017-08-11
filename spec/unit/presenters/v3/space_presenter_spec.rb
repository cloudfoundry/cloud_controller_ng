require 'spec_helper'
require 'presenters/v3/space_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SpacePresenter do
    let(:space) { VCAP::CloudController::Space.make }

    describe '#to_hash' do
      let(:result) { SpacePresenter.new(space).to_hash }

      it 'presents the org as json' do
        expect(result[:guid]).to eq(space.guid)
        expect(result[:created_at]).to eq(space.created_at)
        expect(result[:updated_at]).to eq(space.updated_at)
        expect(result[:name]).to eq(space.name)
        expect(result[:links][:self][:href]).to match(%r{/v3/spaces/#{space.guid}$})
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/spaces/#{space.guid}")
        expect(result[:links][:organization][:href]).to eq("#{link_prefix}/v3/organizations/#{space.organization_guid}")
      end
    end
  end
end
