require 'spec_helper'

module VCAP::CloudController
  describe PortGenerator do
    let(:routing_api_client) { double('routing_api_client', router_group: router_group1) }
    let(:router_group1) { double('router_group1', type: router_group_type, guid: router_group_guid1) }
    let(:router_group_type) { 'tcp' }
    let(:router_group_guid1) { 'router-group-guid1' }

    let(:domain_guid1) { domain1.guid }
    let(:domain1) { SharedDomain.make(router_group_guid: router_group_guid1) }
    let(:generator1) { PortGenerator.new({ 'domain_guid' => domain_guid1 }) }

    describe 'generate_port' do
      it 'generates a port' do
        port = generator1.generate_port(Array(1024..65535))

        expect((1024..65535).cover?(port)).to eq(true)
      end

      it 'runs out of ports' do
        3.times do
          port = generator1.generate_port(Array(1024..1026))
          Route.make(domain: domain1, port: port)
        end

        port = generator1.generate_port(Array(1024..1026))
        expect(port).to eq(-1)
      end

      context 'when there are multi router groups' do
        let(:router_group_guid2) { 'router-group-guid2' }
        let(:router_group2) { double('router_group2', type: router_group_type, guid: router_group_guid2) }

        let(:domain2) { SharedDomain.make(router_group_guid: router_group_guid2) }
        let(:generator2) { PortGenerator.new({ 'domain_guid' => domain2.guid }) }

        it 'hands out the same port for multiple router groups' do
          Route.make(domain: domain1, port: 60001)
          Route.make(domain: domain2, port: 60001)

          port1 = generator1.generate_port(Array(60001..60002))
          port2 = generator2.generate_port(Array(60001..60002))

          expect(port1).to eq(port2)
        end
      end
    end
  end
end
