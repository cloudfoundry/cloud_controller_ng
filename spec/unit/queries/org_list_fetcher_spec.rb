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

    describe '#fetch' do
      it 'fetch_all includes all the orgs with the provided guids' do
        expect(fetcher.fetch([org1.guid, org3.guid, org4.guid]).all).to match_array([
          org1, org3, org4
        ])
      end
    end

    describe '#fetch_all' do
      let(:config) { CloudController::DependencyLocator.instance.config }
      let(:system_org) { Organization.find(name: config[:system_domain_organization]) }

      it 'fetches all the orgs' do
        all_orgs = fetcher.fetch_all
        expect(all_orgs.count).to eq(6)

        expect(all_orgs).to match_array([
          org1, org2, org3, org4, org5, system_org
        ])
      end
    end
  end
end
