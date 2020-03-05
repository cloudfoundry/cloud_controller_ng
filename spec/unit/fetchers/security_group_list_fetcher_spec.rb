require 'spec_helper'
require 'messages/security_group_list_message'
require 'models/runtime/security_group'
require 'fetchers/security_group_list_fetcher'

module VCAP::CloudController
  RSpec.describe SecurityGroupListFetcher do
    let(:fetcher) { SecurityGroupListFetcher }
    let(:message) { SecurityGroupListMessage.from_params(filters) }
    let(:filters) { {} }
    let!(:security_group_1) { SecurityGroup.make }
    let!(:security_group_2) { SecurityGroup.make }
    let!(:security_group_3) { SecurityGroup.make }

    context '#fetch_all' do
      it 'includes all the security_groups' do
        expect(fetcher.fetch_all(message).all).to include(security_group_1, security_group_2, security_group_3)
      end
    end

    describe '#fetch' do
      let(:visible_security_groups) { [security_group_1.guid, security_group_2.guid] }
      let(:security_groups) { fetcher.fetch(message, visible_security_groups) }

      context 'when no filters are specified' do
        it 'returns all of the security groups' do
          expect(security_groups.all).to contain_exactly(security_group_1, security_group_2)
        end
      end

      context 'when we filter on guid' do
        let(:filters) { { guids: [security_group_1.guid] } }
        it 'returns only the security groups with the specified guids' do
          expect(security_groups.all).to contain_exactly(security_group_1)
        end
      end

      context 'when we filter on name' do
        let(:filters) { { names: [security_group_1.name] } }
        it 'returns only the security groups with the specified names' do
          expect(security_groups.all).to contain_exactly(security_group_1)
        end
      end

      context 'when we filter on running_space_guid' do
        let(:associated_space) { Space.make }
        let(:filters) { { running_space_guids: [associated_space.guid] } }

        before do
          security_group_1.add_space(associated_space)
        end

        it 'returns only the security groups applied to running applications in the specified space' do
          expect(security_groups.all).to contain_exactly(security_group_1)
        end
      end

      context 'when we filter on staging_space_guid' do
        let(:associated_space) { Space.make }
        let(:filters) { { staging_space_guids: [associated_space.guid] } }

        before do
          security_group_2.add_staging_space(associated_space)
        end

        it 'returns only the security groups applied to staging applications in the specified space' do
          expect(security_groups.all).to contain_exactly(security_group_2)
        end
      end

      context 'when we filter on globally_enabled_running' do
        let(:filters) { { globally_enabled_running: 'true' } }

        before do
          security_group_1.update(running_default: true)
        end

        it 'returns only the security groups with the specified globally_enabled running property' do
          expect(security_groups.all).to contain_exactly(security_group_1)
        end
      end

      context 'when we filter on globally_enabled_staging' do
        let(:filters) { { globally_enabled_staging: 'true' } }

        before do
          security_group_1.update(staging_default: true)
        end

        it 'returns only the security groups with the specified globally_enabled staging property' do
          expect(security_groups.all).to contain_exactly(security_group_1)
        end
      end
    end
  end
end
