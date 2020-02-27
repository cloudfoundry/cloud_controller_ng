require 'spec_helper'
require 'presenters/v3/security_group_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SecurityGroupPresenter do
    let(:security_group) { VCAP::CloudController::SecurityGroup.make(
      guid: 'security-group-guid',
      staging_default: false,
      running_default: true
    )
    }

    before do
      security_group.add_space(space1)
      security_group.add_staging_space(space2)
    end

    describe '#to_hash' do
      let(:space1) { VCAP::CloudController::Space.make(guid: 'guid1') }
      let(:space2) { VCAP::CloudController::Space.make(guid: 'guid2') }
      let(:result) { SecurityGroupPresenter.new(security_group).to_hash }

      it 'presents the security group as json' do
        expect(result[:guid]).to eq(security_group.guid)
        expect(result[:created_at]).to eq(security_group.created_at)
        expect(result[:updated_at]).to eq(security_group.updated_at)
        expect(result[:name]).to eq(security_group.name)
        expect(result[:globally_enabled][:running]).to eq(true)
        expect(result[:globally_enabled][:staging]).to eq(false)
        expect(result[:relationships][:running_spaces][:data].length).to eq(1)
        expect(result[:relationships][:staging_spaces][:data].length).to eq(1)
        expect(result[:relationships][:running_spaces][:data][0][:guid]).to eq(space1.guid)
        expect(result[:relationships][:staging_spaces][:data][0][:guid]).to eq(space2.guid)
        expect(result[:links][:self][:href]).to match(%r{/v3/security_groups/#{security_group.guid}$})
      end
    end
  end
end
