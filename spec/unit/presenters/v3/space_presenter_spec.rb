require 'spec_helper'
require 'presenters/v3/space_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SpacePresenter do
    let(:space) { VCAP::CloudController::Space.make }
    let!(:release_label) do
      VCAP::CloudController::SpaceLabelModel.make(
        key_name: 'release',
        value: 'stable',
        space_guid: space.guid
      )
    end

    let!(:potato_label) do
      VCAP::CloudController::SpaceLabelModel.make(
        key_prefix: 'maine.gov',
        key_name: 'potato',
        value: 'mashed',
        space_guid: space.guid
      )
    end

    describe '#to_hash' do
      let(:result) { SpacePresenter.new(space).to_hash }

      it 'presents the space as json' do
        expect(result[:guid]).to eq(space.guid)
        expect(result[:created_at]).to eq(space.created_at)
        expect(result[:updated_at]).to eq(space.updated_at)
        expect(result[:name]).to eq(space.name)
        expect(result[:links][:self][:href]).to match(%r{/v3/spaces/#{space.guid}$})
        expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/spaces/#{space.guid}")
        expect(result[:links][:organization][:href]).to eq("#{link_prefix}/v3/organizations/#{space.organization_guid}")
        expect(result[:relationships][:organization][:data][:guid]).to eq(space.organization_guid)
        expect(result[:metadata][:labels]).to eq('release' => 'stable', 'maine.gov/potato' => 'mashed')
      end
    end
  end
end
