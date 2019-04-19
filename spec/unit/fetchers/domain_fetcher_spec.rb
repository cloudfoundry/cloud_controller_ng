require 'spec_helper'
require 'messages/domains_list_message'
require 'messages/domain_show_message'
require 'fetchers/domain_fetcher'

module VCAP::CloudController
  RSpec.describe DomainFetcher do
    describe '#fetch_all_for_orgs' do
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
          domains = DomainFetcher.fetch_all_for_orgs([])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2')
        end
      end

      context 'when the user can see all shared private domains' do
        it 'does org1' do
          domains = DomainFetcher.fetch_all_for_orgs([org1.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2', 'private_domain1', 'private_domain2')
        end

        it 'does org2' do
          domains = DomainFetcher.fetch_all_for_orgs([org2.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1', 'public_domain2')
        end

        it 'does org3' do
          domains = DomainFetcher.fetch_all_for_orgs([org3.guid])
          expect(domains.map(&:guid)).to contain_exactly('public_domain1',
            'public_domain2', 'private_domain1', 'private_domain3')
        end

        it 'returns readable domains for multiple orgs' do
          domains = DomainFetcher.fetch_all_for_orgs([org1.guid, org3.guid])
          expect(domains.map(&:guid)).to contain_exactly(
            'public_domain1', 'public_domain2',
            'private_domain1', 'private_domain2', 'private_domain3'
          )
        end

        it 'returns readable domains for multiple orgs' do
          domains = DomainFetcher.fetch_all_for_orgs([org2.guid, org3.guid])
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

      context 'when fetching a single domain by guid' do
        let (:message) {
          DomainShowMessage.new({ guid: domain_guid_filter })
        }

        context 'when the domain is shared' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:public_domain1) { SharedDomain.make(guid: 'public_domain1') }
          let!(:domain_guid_filter) { public_domain1.guid }

          it 'returns only public_domain1' do
            results = DomainFetcher.fetch(message, [org1.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq('public_domain1')
          end
        end

        context 'when the domain is private' do
          context 'when the user can read from the owning org' do
            let!(:org1) { Organization.make(guid: 'org1') }
            let!(:private_domain) { PrivateDomain.make(guid: 'private_domain', owning_organization: org1) }
            let!(:domain_guid_filter) { private_domain.guid }

            it 'returns only the private domain' do
              results = DomainFetcher.fetch(message, [org1.guid]).all
              expect(results.length).to eq(1)
              expect(results[0].guid).to eq('private_domain')
            end
          end

          context 'when the user can read from a shared org' do
            let!(:org1) { Organization.make(guid: 'org1') }
            let!(:private_domain) { PrivateDomain.make(guid: 'private_domain') }
            let!(:domain_guid_filter) { private_domain.guid }

            before do
              org1.add_private_domain(private_domain)
            end

            it 'returns the private domain' do
              results = DomainFetcher.fetch(message, [org1.guid]).all
              expect(results.length).to eq(1)
              expect(results[0].guid).to eq('private_domain')
            end
          end

          context 'when the user can not read from any associated org' do
            let!(:org1) { Organization.make(guid: 'org1') }
            let!(:org2) { Organization.make(guid: 'org2') }
            let!(:private_domain) { PrivateDomain.make(guid: 'private_domain') }
            let!(:domain_guid_filter) { private_domain.guid }

            before do
              org2.add_private_domain(private_domain)
            end

            it 'returns no domains' do
              results = DomainFetcher.fetch(message, [org1.guid]).all
              expect(results.length).to eq(0)
            end
          end
        end
      end

      context 'when fetching domains by name' do
        let (:message) {
          DomainsListMessage.from_params({ names: domain_name_filter })
        }

        context 'when the matching domain is shared' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:public_domain1) { SharedDomain.make(guid: 'named-domain-1', name: 'named-domain-1.com') }
          let!(:public_domain2) { SharedDomain.make(guid: 'named-domain-2', name: 'named-domain-2.com') }
          let!(:domain_name_filter) { public_domain2.name }

          it 'returns only public_domain1' do
            results = DomainFetcher.fetch(message, [org1.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq('named-domain-2')
          end
        end

        context 'when there is no visible domain with given name' do
          let!(:domain_name_filter) { 'not-visible-domain.com' }

          it 'returns no domains' do
            results = DomainFetcher.fetch(message, []).all
            expect(results.length).to eq(0)
          end
        end
      end
    end
  end
end
