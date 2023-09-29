require 'spec_helper'

module VCAP::CloudController
  RSpec.describe PortGenerator do
    let(:routing_api_client) { double('routing_api_client', router_group: router_group1) }
    let(:router_group1) { double('router_group1', type: router_group_type, guid: router_group_guid1) }
    let(:router_group_type) { 'tcp' }
    let(:router_group_guid1) { 'router-group-guid1' }

    let(:domain_guid1) { domain1.guid }
    let(:domain1) { SharedDomain.make(router_group_guid: router_group_guid1) }
    let(:space_quota) { SpaceQuotaDefinition.make }
    let(:space) { Space.make(organization: space_quota.organization, space_quota_definition: space_quota) }
    let(:dependency_double) { double('dependency_locator', routing_api_client:) }

    before do
      allow_any_instance_of(RouteValidator).to receive(:validate)
      allow(CloudController::DependencyLocator).to receive(:instance).and_return(dependency_double)
    end

    describe 'generate_port' do
      it 'generates a port' do
        port = PortGenerator.generate_port(domain_guid1, Array(1024..65_535))

        expect((1024..65_535).cover?(port)).to be(true)
      end

      it 'runs out of ports' do
        3.times do
          port = PortGenerator.generate_port(domain_guid1, Array(1024..1026))
          Route.make(domain: domain1, port: port, space: space)
        end

        port = PortGenerator.generate_port(domain_guid1, Array(1024..1026))
        expect(port).to eq(-1)
      end

      context 'when there are multi router groups' do
        let(:router_group_guid2) { 'router-group-guid2' }
        let(:router_group2) { double('router_group2', type: router_group_type, guid: router_group_guid2) }

        let(:domain2) { SharedDomain.make(router_group_guid: router_group_guid2) }

        it 'hands out the same port for multiple router groups' do
          Route.make(domain: domain1, port: 60_001, space: space)
          Route.make(domain: domain2, port: 60_001, space: space)

          port1 = PortGenerator.generate_port(domain2.guid, Array(60_001..60_002))
          port2 = PortGenerator.generate_port(domain2.guid, Array(60_001..60_002))

          expect(port1).to eq(port2)
        end
      end
    end
  end
end
