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

    describe '#to_hash' do
      let(:result) { SecurityGroupPresenter.new(security_group).to_hash }

      it 'presents the security group as json' do
        expect(result[:guid]).to eq(security_group.guid)
        expect(result[:created_at]).to eq(security_group.created_at)
        expect(result[:updated_at]).to eq(security_group.updated_at)
        expect(result[:name]).to eq(security_group.name)
        expect(result[:globally_enabled][:running]).to eq(true)
        expect(result[:globally_enabled][:staging]).to eq(false)
        expect(result[:links][:self][:href]).to match(%r{/v3/security_groups/#{security_group.guid}$})
      end
    end
  end
end
