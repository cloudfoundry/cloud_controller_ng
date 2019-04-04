require 'spec_helper'
require 'messages/domains_list_message'
require 'fetchers/domain_fetcher'

module VCAP::CloudController
  RSpec.describe DomainFetcher do
    describe '#fetch_all' do
      before do
        Domain.dataset.destroy
      end
      let!(:org1) { Organization.make(guid: 'org1') }
      let!(:org2) { Organization.make(guid: 'org2') }
      let!(:org3) { Organization.make(guid: 'org3') }
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
          domains = DomainFetcher.fetch_all([])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2')
        end
      end

      context 'when the user can see all shared private domains' do
        it 'does org1' do
          domains = DomainFetcher.fetch_all([org1.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2', 'private_domain1', 'private_domain2')
        end

        it 'does org2' do
          domains = DomainFetcher.fetch_all([org2.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2')
        end

        it 'does org3' do
          domains = DomainFetcher.fetch_all([org3.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1',
            'public_domain2', 'private_domain1', 'private_domain3')
        end

        it 'returns readable domains for multiple orgs' do
          domains = DomainFetcher.fetch_all([org1.guid, org3.guid])
          expect(domains.map(&:guid)).to contain_exactly(
            'public_domain1', 'public_domain2',
            'private_domain1', 'private_domain2', 'private_domain3'
          )
        end

        it 'returns readable domains for multiple orgs' do
          domains = DomainFetcher.fetch_all([org2.guid, org3.guid])
          expect(domains.map(&:guid)).to contain_exactly(
            'public_domain1', 'public_domain2',
            'private_domain1', 'private_domain3'
          )
        end
      end
    end

    describe '#fetch' do
      before do
        Domain.dataset.destroy
      end
      context 'when the domain is shared' do
        let!(:org1) { Organization.make(guid: 'org1') }
        let!(:public_domain1) { SharedDomain.make(guid: 'public_domain1') }

        it 'returns public_domain1' do
          domain = DomainFetcher.fetch([org1.guid], public_domain1.guid)
          expect(domain.guid).to eq('public_domain1')
        end
      end

      context 'when the domain is private' do
        context 'when the user can read from the owning org' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:private_domain) { PrivateDomain.make(guid: 'private_domain', owning_organization: org1) }

          it 'returns the private domain' do
            domain = DomainFetcher.fetch([org1.guid], private_domain.guid)
            expect(domain.guid).to eq('private_domain')
          end
        end

        context 'when the user can read from a shared org' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:private_domain) { PrivateDomain.make(guid: 'private_domain') }

          before do
            org1.add_private_domain(private_domain)
          end

          it 'returns the private domain' do
            domain = DomainFetcher.fetch([org1.guid], private_domain.guid)
            expect(domain.guid).to eq('private_domain')
          end
        end

        context 'when the user can not read from any associated org' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:org2) { Organization.make(guid: 'org2') }
          let!(:private_domain) { PrivateDomain.make(guid: 'private_domain') }

          before do
            org2.add_private_domain(private_domain)
          end

          it 'returns no domains' do
            domain = DomainFetcher.fetch([org1.guid], private_domain.guid)
            expect(domain).to be_nil
          end
        end
      end
    end
  end
end
