require 'spec_helper'
require 'presenters/v3/security_group_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe SecurityGroupPresenter do
    let(:security_group) do
      VCAP::CloudController::SecurityGroup.make(
        guid: 'security-group-guid',
        staging_default: false,
        running_default: true,
        rules: [
          {
            protocol: 'tcp',
            destination: '10.10.10.0/24',
            ports: '443,80,8080'
          },
        ]
      )
    end

    before do
      security_group.add_space(space1)
      security_group.add_staging_space(space2)
    end

    describe '#to_hash' do
      let(:result) { SecurityGroupPresenter.new(security_group, visible_space_guids: visible_space_guids).to_hash }

      let(:space1) { VCAP::CloudController::Space.make(guid: 'guid1') }
      let(:space2) { VCAP::CloudController::Space.make(guid: 'guid2') }
      let(:visible_space_guids) { [space1.guid, space2.guid] }

      it 'presents the security group as json' do
        expect(result[:guid]).to eq(security_group.guid)
        expect(result[:created_at]).to eq(security_group.created_at)
        expect(result[:updated_at]).to eq(security_group.updated_at)
        expect(result[:name]).to eq(security_group.name)
        expect(result[:globally_enabled][:running]).to eq(true)
        expect(result[:globally_enabled][:staging]).to eq(false)
        expect(result[:rules]).to eq([
          {
            'protocol' => 'tcp',
            'destination' => '10.10.10.0/24',
            'ports' => '443,80,8080'
          }
        ])
        expect(result[:relationships][:running_spaces][:data].length).to eq(1)
        expect(result[:relationships][:staging_spaces][:data].length).to eq(1)
        expect(result[:relationships][:running_spaces][:data][0][:guid]).to eq(space1.guid)
        expect(result[:relationships][:staging_spaces][:data][0][:guid]).to eq(space2.guid)
        expect(result[:links][:self][:href]).to match(%r{/v3/security_groups/#{security_group.guid}$})
      end

      describe 'when some associated spaces are not visible' do
        let(:visible_space_guids) { [] }

        it 'does not display the spaces that are not visible' do
          expect(result[:relationships][:running_spaces][:data]).to be_empty
          expect(result[:relationships][:staging_spaces][:data]).to be_empty
        end
      end
    end
  end
end
