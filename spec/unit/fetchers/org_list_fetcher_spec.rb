require 'spec_helper'
require 'messages/orgs_list_message'
require 'fetchers/org_list_fetcher'

module VCAP::CloudController
  RSpec.describe OrgListFetcher do
    let!(:org1) { Organization.make(name: 'Marmot') }
    let!(:org2) { Organization.make(name: 'Rat') }
    let!(:org3) { Organization.make(name: 'Beaver') }
    let!(:org4) { Organization.make(name: 'Capybara') }
    let!(:org5) { Organization.make(name: 'Groundhog') }
    let(:some_org_guids) { [org1.guid, org3.guid, org4.guid] }

    let(:fetcher) { OrgListFetcher }

    let(:message) { OrgsListMessage.from_params({}) }

    describe '#fetch' do
      it 'includes all the orgs with the provided guids' do
        results = fetcher.fetch(message: message, guids: some_org_guids).all
        expect(results).to match_array([org1, org3, org4])
      end

      describe 'eager loading associated resources' do
        let(:some_org_guids) { [org1.guid, org3.guid] }

        it 'eager loads the specified resources for all orgs' do
          results = fetcher.fetch(message: message, guids: some_org_guids, eager_loaded_associations: [:quota_definition, :labels]).all

          expect(results.first.associations.key?(:quota_definition)).to be true
          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false
        end
      end

      describe 'filtering on message' do
        context 'when org names are provided' do
          let(:message) { OrgsListMessage.from_params names: ['Marmot', 'Capybara'] }

          it 'returns the correct set of orgs' do
            results = fetcher.fetch(message: message, guids: some_org_guids).all
            expect(results).to match_array([org1, org4])
          end

          context 'respects any provided guids' do
            let(:message) { OrgsListMessage.from_params names: ['Marmot', 'Rat'] }

            it 'does not return orgs asked for if they are not part of the array passed into #fetch' do
              results = fetcher.fetch(message: message, guids: some_org_guids).all
              expect(results).to match_array([org1])
            end
          end
        end

        context 'when org guids are provided' do
          let(:all_org_guids) { [org1.guid, org2.guid, org3.guid, org4.guid, org5.guid] }
          let(:message) { OrgsListMessage.from_params guids: some_org_guids }

          it 'returns the correct set of orgs' do
            results = fetcher.fetch(message: message, guids: all_org_guids).all
            expect(results).to match_array([org1, org3, org4])
          end

          context 'respects any provided guids' do
            let(:message) { OrgsListMessage.from_params guids: [org1.guid, org2.guid] }

            it 'does not return orgs asked for if they are not part of the array passed into #fetch' do
              results = fetcher.fetch(message: message, guids: some_org_guids).all
              expect(results).to match_array([org1])
            end
          end
        end
      end
    end

    describe '#fetch_all' do
      let(:config) { CloudController::DependencyLocator.instance.config }
      let(:system_org) { Organization.find(name: config.get(:system_domain_organization)) }

      it 'fetches all the orgs' do
        all_orgs = fetcher.fetch_all(message: message)
        expect(all_orgs.count).to eq(6)

        expect(all_orgs).to match_array([
          org1, org2, org3, org4, org5, system_org
        ])
      end

      describe 'eager loading associated resources' do
        let(:some_org_guids) { [org1.guid, org3.guid] }

        it 'eager loads the specified resources for all orgs' do
          results = fetcher.fetch_all(message: message, eager_loaded_associations: [:quota_definition, :labels]).all

          expect(results).to match_array([
            org1, org2, org3, org4, org5, system_org
          ])

          expect(results.first.associations.key?(:quota_definition)).to be true
          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false
        end
      end

      describe 'filtering on message' do
        context 'when org names are provided' do
          let(:message) { OrgsListMessage.from_params names: ['Marmot', 'Capybara', 'Groundhog'] }

          it 'returns the correct set of orgs' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([org1, org4, org5])
          end
        end

        context 'when org guids are provided' do
          let(:message) { OrgsListMessage.from_params guids: some_org_guids }

          it 'returns the correct set of orgs' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([org1, org3, org4])
          end
        end

        context 'when a label_selector is provided' do
          let(:message) do OrgsListMessage.from_params({ 'label_selector' => 'key=value' })
          end
          let!(:org1label) { OrganizationLabelModel.make(key_name: 'key', value: 'value', organization: org1) }
          let!(:org2label) { OrganizationLabelModel.make(key_name: 'key2', value: 'value2', organization: org2) }

          it 'returns the correct set of orgs' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to contain_exactly(org1)
          end
        end
      end
    end

    describe '#fetch_for_isolation_segment' do
      let(:isolation_segment) { IsolationSegmentModel.make }
      let(:assigner) { IsolationSegmentAssign.new }
      let(:message) { OrgsListMessage.from_params isolation_segment_guid: isolation_segment.guid }
      let(:readable_org_guids) { [org1.guid, org2.guid] }

      before do
        assigner.assign(isolation_segment, [org1, org2, org5])
      end

      it 'returns the correct isolation segment' do
        returned_isolation_segment, _ = fetcher.fetch_for_isolation_segment(message: message, guids: readable_org_guids)
        expect(returned_isolation_segment.guid).to eq(isolation_segment.guid)
      end

      it 'fetches the orgs that the user can see associated with the iso seg' do
        _, results = fetcher.fetch_for_isolation_segment(message: message, guids: readable_org_guids)
        expect(results.all).to match_array([org1, org2])
      end

      describe 'eager loading associated resources' do
        it 'eager loads the specified resources for all orgs' do
          _, org_ds = fetcher.fetch_for_isolation_segment(message: message, guids: readable_org_guids, eager_loaded_associations: [:quota_definition, :labels])
          results = org_ds.all

          expect(results).to match_array([org1, org2])

          expect(results.first.associations.key?(:quota_definition)).to be true
          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false
        end
      end
    end

    describe '#fetch_all_for_isoation_segments' do
      let(:isolation_segment) { IsolationSegmentModel.make }
      let(:assigner) { IsolationSegmentAssign.new }
      let(:message) { OrgsListMessage.from_params isolation_segment_guid: isolation_segment.guid }

      before do
        assigner.assign(isolation_segment, [org1, org2, org5])
      end

      it 'returns the correct isolation segment' do
        returned_isolation_segment, _ = fetcher.fetch_all_for_isolation_segment(message: message)
        expect(returned_isolation_segment.guid).to eq(isolation_segment.guid)
      end

      it 'fetches all the orgs associated with the iso seg' do
        _, results = fetcher.fetch_all_for_isolation_segment(message: message)
        expect(results.all).to match_array([org1, org2, org5])
      end

      describe 'eager loading associated resources' do
        it 'eager loads the specified resources for all orgs' do
          _, org_ds = fetcher.fetch_all_for_isolation_segment(message: message, eager_loaded_associations: [:quota_definition, :labels])
          results = org_ds.all

          expect(results).to match_array([org1, org2, org5])

          expect(results.first.associations.key?(:quota_definition)).to be true
          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false
        end
      end
    end
  end
end
