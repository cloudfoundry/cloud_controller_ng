require 'spec_helper'
require 'fetchers/security_group_fetcher'

module VCAP::CloudController
  RSpec.describe SecurityGroupFetcher do
    let(:fetcher) { SecurityGroupFetcher }
    let!(:security_group_1) { SecurityGroup.make }
    let!(:security_group_2) { SecurityGroup.make }
    let(:associated_space) { Space.make }
    let(:visible_security_groups) { nil }
    let(:security_group) { fetcher.fetch(security_group_1.guid, visible_security_groups) }

    describe '#fetch' do
      it 'eager loads running and staging spaces' do
        expect(security_group.associations.keys).to contain_exactly(:spaces, :staging_spaces)
      end

      it 'eager loads space guids only' do
        security_group_1.add_space(associated_space)
        security_group_1.add_staging_space(associated_space)
        [:spaces, :staging_spaces].each do |key|
          expect(security_group.associations[key].length).to eq(1)
          expect(security_group.associations[key].first.keys).to contain_exactly(:guid)
        end
      end

      it 'returns the security group' do
        expect(security_group).to eq(security_group_1)
      end

      context 'security group guid in visible_security_group_guids' do
        let(:visible_security_groups) { [security_group_1.guid] }

        it 'returns the security group' do
          expect(security_group).to eq(security_group_1)
        end
      end

      context 'security group guid not in visible_security_group_guids' do
        let(:visible_security_groups) { [security_group_2.guid] }

        it 'returns nil' do
          expect(security_group).to be_nil
        end
      end
    end
  end
end
