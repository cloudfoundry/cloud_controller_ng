require 'spec_helper'
require 'messages/orgs_list_message'
require 'queries/org_list_fetcher'

module VCAP::CloudController
  RSpec.describe OrgListFetcher do
    let!(:org1) { Organization.make(name: 'Marmot') }
    let!(:org2) { Organization.make(name: 'Rat') }
    let!(:org3) { Organization.make(name: 'Beaver') }
    let!(:org4) { Organization.make(name: 'Capybara') }
    let!(:org5) { Organization.make(name: 'Groundhog') }

    let(:fetcher) { described_class.new }

    let(:message) { OrgsListMessage.new }

    describe '#fetch' do
      let(:org_guids) { [org1.guid, org3.guid, org4.guid] }

      it 'includes all the orgs with the provided guids' do
        results = fetcher.fetch(message: message, guids: org_guids).all
        expect(results).to match_array([org1, org3, org4])
      end

      describe 'filtering on message' do
        context 'when org names are provided' do
          let(:message) { OrgsListMessage.new names: ['Marmot', 'Capybara'] }

          it 'returns the correct set of tasks' do
            results = fetcher.fetch(message: message, guids: org_guids).all
            expect(results).to match_array([org1, org4])
          end
        end
      end
    end

    describe '#fetch_all' do
      let(:config) { CloudController::DependencyLocator.instance.config }
      let(:system_org) { Organization.find(name: config[:system_domain_organization]) }

      it 'fetches all the orgs' do
        all_orgs = fetcher.fetch_all(message: message)
        expect(all_orgs.count).to eq(6)

        expect(all_orgs).to match_array([
          org1, org2, org3, org4, org5, system_org
        ])
      end

      describe 'filtering on message' do
        context 'when org names are provided' do
          let(:message) { OrgsListMessage.new names: ['Marmot', 'Capybara', 'Groundhog'] }

          it 'returns the correct set of tasks' do
            results = fetcher.fetch_all(message: message).all
            expect(results).to match_array([org1, org4, org5])
          end
        end
      end
    end
  end
end
