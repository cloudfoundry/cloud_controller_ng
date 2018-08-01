require 'spec_helper'

module VCAP::CloudController
  RSpec.describe OrganizationReservedRoutePorts do
    let(:organization) { Organization.make }

    subject(:organization_routes) { OrganizationReservedRoutePorts.new(organization) }

    describe '#count' do
      context 'when the org has no spaces' do
        it 'has no reserved ports' do
          expect(subject.count).to eq 0
        end
      end

      context 'when there are spaces' do
        let(:space_quota) { SpaceQuotaDefinition.make(organization: organization) }
        let(:space) { Space.make(organization: organization, space_quota_definition: space_quota) }
        let(:space2) { Space.make(organization: organization, space_quota_definition: space_quota) }

        it 'has no reserved ports' do
          expect(subject.count).to eq 0
        end

        context 'and there are multiple ports, reserved or otherwise' do
          let!(:mock_router_api_client) do
            router_group = double('router_group', type: 'tcp', reservable_ports: [4444, 6000, 1234, 3455, 2222])
            routing_api_client = double('routing_api_client', router_group: router_group, enabled?: true)
            allow(CloudController::DependencyLocator).to receive(:instance).and_return(double(:api_client, routing_api_client: routing_api_client))
          end

          before do
            domain = SharedDomain.make(router_group_guid: '123')
            Route.make(host: '', space: space, domain: domain, port: 1234)
            Route.make(host: '', space: space, domain: domain, port: 3455)
            Route.make(host: '', space: space, domain: domain, port: 4444)
            Route.make(host: '', space: space2, domain: domain, port: 6000)
            Route.make(host: '', space: space2, domain: domain, port: 2222)
            Route.make(space: space)
          end

          it 'should have return the number of reserved ports' do
            expect(subject.count).to eq 5
          end
        end
      end
    end
  end
end
