require 'spec_helper'
require 'messages/domains_list_message'
require 'fetchers/domain_list_fetcher'

module VCAP::CloudController
  RSpec.describe DomainListFetcher do
    describe '#fetch' do
      before do
        Domain.dataset.destroy
      end
      let!(:org1) { FactoryBot.create(:organization, guid: 'org1') }
      let!(:org2) { FactoryBot.create(:organization, guid: 'org2') }
      let!(:org3) { FactoryBot.create(:organization, guid: 'org3') }
      # org1 will share private domain(s) with org3
      let!(:public_domain1) { SharedDomain.make(guid: 'public_domain1') }
      let!(:public_domain2) { SharedDomain.make(guid: 'public_domain2') }
      let!(:private_domain1) { PrivateDomain.make(guid: 'private_domain1', owning_organization: org1) }
      let!(:private_domain2) { PrivateDomain.make(guid: 'private_domain2', owning_organization: org1) }
      let!(:private_domain3) { PrivateDomain.make(guid: 'private_domain3', owning_organization: org3) }

      before do
        org3.add_private_domain(private_domain1)
      end

      context 'when there are no readable org guids' do
        it 'does something' do
          domains = DomainListFetcher.new.fetch([])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2')
        end
      end

      context 'when the user can see all shared private domains' do
        it 'does org1' do
          domains = DomainListFetcher.new.fetch([org1.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2', 'private_domain1', 'private_domain2')
        end

        it 'does org2' do
          domains = DomainListFetcher.new.fetch([org2.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2')
        end

        it 'does org3' do
          domains = DomainListFetcher.new.fetch([org3.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1',
            'public_domain2', 'private_domain1', 'private_domain3')
        end

        it 'returns readable domains for multiple orgs' do
          domains = DomainListFetcher.new.fetch([org1.guid, org3.guid])
          expect(domains.map(&:guid)).to contain_exactly(
            'public_domain1', 'public_domain2',
              'private_domain1', 'private_domain2', 'private_domain3'
            )
        end

        it 'returns readable domains for multiple orgs' do
          domains = DomainListFetcher.new.fetch([org2.guid, org3.guid])
          expect(domains.map(&:guid)).to contain_exactly(
            'public_domain1', 'public_domain2',
            'private_domain1', 'private_domain3'
          )
        end
      end
    end
  end
end
