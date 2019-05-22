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
      let!(:shared_domain1) { SharedDomain.make(guid: 'shared_domain1') }
      let!(:shared_domain2) { SharedDomain.make(guid: 'shared_domain2') }
      let!(:private_domain1) { PrivateDomain.make(guid: 'private_domain1', owning_organization: org1) }
      let!(:private_domain2) { PrivateDomain.make(guid: 'private_domain2', owning_organization: org1) }
      let!(:private_domain3) { PrivateDomain.make(guid: 'private_domain3', owning_organization: org3) }

      before do
        org3.add_private_domain(private_domain1)
      end

      context 'when there are no readable org guids' do
        it 'lists shared domains only' do
          domains = DomainFetcher.fetch_all_for_orgs([])
          expect(domains.map(&:guid)).to contain_exactly('shared_domain1', 'shared_domain2')
        end
      end

      context 'when the user can see all shared private domains' do
        it 'gets org1' do
          domains = DomainFetcher.fetch_all_for_orgs([org1.guid])
          expect(domains.map(&:guid)).to contain_exactly('shared_domain1', 'shared_domain2', 'private_domain1', 'private_domain2')
        end

        it 'gets org2' do
          domains = DomainFetcher.fetch_all_for_orgs([org2.guid])
          expect(domains.map(&:guid)).to contain_exactly('shared_domain1', 'shared_domain2')
        end

        it 'gets org3' do
          domains = DomainFetcher.fetch_all_for_orgs([org3.guid])
          expect(domains.map(&:guid)).to contain_exactly('shared_domain1',
            'shared_domain2', 'private_domain1', 'private_domain3')
        end

        it 'returns readable domains for multiple orgs' do
          domains = DomainFetcher.fetch_all_for_orgs([org1.guid, org3.guid])
          expect(domains.map(&:guid)).to contain_exactly(
            'shared_domain1', 'shared_domain2',
            'private_domain1', 'private_domain2', 'private_domain3'
          )
        end

        it 'returns readable domains for multiple orgs' do
          domains = DomainFetcher.fetch_all_for_orgs([org2.guid, org3.guid])
          expect(domains.map(&:guid)).to contain_exactly(
            'shared_domain1', 'shared_domain2',
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
        let(:message) {
          DomainShowMessage.new({ guid: domain_guid_filter })
        }

        context 'when the domain is shared' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:shared_domain1) { SharedDomain.make(guid: 'shared_domain1') }
          let!(:domain_guid_filter) { shared_domain1.guid }

          it 'returns only the shared domain for the given guid' do
            results = DomainFetcher.fetch(message, [org1.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq('shared_domain1')
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
        let(:message) {
          DomainsListMessage.from_params({ names: domain_name_filter })
        }

        context 'when the matching domain is shared' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:shared_domain1) { SharedDomain.make(guid: 'named-domain-1', name: 'named-domain-1.com') }
          let!(:shared_domain2) { SharedDomain.make(guid: 'named-domain-2', name: 'named-domain-2.com') }
          let!(:domain_name_filter) { shared_domain2.name }

          it 'only returns the matching domain' do
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

      context 'when fetching domains by guid' do
        let(:message) {
          DomainsListMessage.from_params({ guids: domain_guid_filter })
        }

        context 'when the matching domain is shared' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:shared_domain1) { SharedDomain.make(guid: 'guid-1') }
          let!(:shared_domain2) { SharedDomain.make(guid: 'guid-2') }
          let!(:domain_guid_filter) { shared_domain2.guid }

          it 'only returns the matching domain' do
            results = DomainFetcher.fetch(message, [org1.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].guid).to eq('guid-2')
          end
        end

        context 'when there is no visible domain with given guid' do
          let!(:domain_guid_filter) { 'not-visible-domain.com' }

          it 'returns no domains' do
            results = DomainFetcher.fetch(message, []).all
            expect(results.length).to eq(0)
          end
        end
      end

      context 'when fetching domains by org_guids' do
        let(:message) {
          DomainsListMessage.from_params({ organization_guids: organization_guid_filter })
        }

        context 'when the matching domain is shared' do
          let!(:org1) { Organization.make(guid: 'org1') }
          let!(:org2) { Organization.make(guid: 'org2') }
          let!(:private_domain1) { PrivateDomain.make(owning_organization: org1, name: 'named-domain-1.com') }
          let!(:private_domain2) { PrivateDomain.make(owning_organization: org2, name: 'named-domain-2.com') }
          let!(:organization_guid_filter) { org1.guid }

          it 'returns only privates_domain1' do
            results = DomainFetcher.fetch(message, [org1.guid, org2.guid]).all
            expect(results.length).to eq(1)
            expect(results[0].name).to eq('named-domain-1.com')
          end
        end

        context 'when there is no visible domain with given name' do
          let!(:organization_guid_filter) { 'not-existing-org-guid' }

          it 'returns no domains' do
            results = DomainFetcher.fetch(message, []).all
            expect(results.length).to eq(0)
          end
        end
      end

      context 'when fetching domains by label selector' do
        let!(:org1) { Organization.make(guid: 'org1') }
        let!(:shared_domain1) { SharedDomain.make(guid: 'named-domain-1', name: 'named-domain-1.com') }
        let!(:shared_domain2) { SharedDomain.make(guid: 'named-domain-2', name: 'named-domain-2.com') }
        let!(:domain_label) do
          VCAP::CloudController::DomainLabelModel.make(resource_guid: shared_domain1.guid, key_name: 'dog', value: 'scooby-doo')
        end

        let!(:sad_domain_label) do
          VCAP::CloudController::DomainLabelModel.make(resource_guid: shared_domain2.guid, key_name: 'dog', value: 'poodle')
        end

        let(:results) { DomainFetcher.fetch(message, [org1.guid]).all }

        context 'only the label_selector is present' do
          let(:message) {
            DomainsListMessage.from_params({ 'label_selector' => 'dog in (chihuahua,scooby-doo)' })
          }
          it 'returns only the domain whose label matches' do
            expect(results.length).to eq(1)
            expect(results[0]).to eq(shared_domain1)
          end
        end

        context 'and other filters are present' do
          let(:message) {
            DomainsListMessage.from_params({ 'names' => 'dom.com', 'label_selector' => 'dog in (chihuahua,scooby-doo)' })
          }

          let!(:happiest_domain) { SharedDomain.make(name: 'dom.com') }
          let!(:happiest_domain_label) do
            VCAP::CloudController::DomainLabelModel.make(resource_guid: happiest_domain.guid, key_name: 'dog', value: 'scooby-doo')
          end

          it 'returns the desired app' do
            expect(results).to contain_exactly(happiest_domain)
          end
        end
      end
    end
  end
end
