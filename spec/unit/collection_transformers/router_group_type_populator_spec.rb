require 'spec_helper'

module VCAP::CloudController
  describe RouterGroupTypePopulator do
    let(:routing_api_client) { double(RoutingApi::Client) }
    let(:router_group_type_populator) { RouterGroupTypePopulator.new(routing_api_client) }
    let(:domain1) { SharedDomain.new(name: '1', router_group_guid: 'guid1') }
    let(:domain2) { SharedDomain.new(name: '2', router_group_guid: 'guid2') }
    let(:domain3) { SharedDomain.new(name: '3', router_group_guid: nil) }
    let(:domain4) { SharedDomain.new(name: '4', router_group_guid: 'guid3') }
    let(:domains) { [domain1, domain2, domain3, domain4] }

    before do
      allow(routing_api_client).to receive(:router_groups).and_return([RoutingApi::RouterGroup.new({ 'guid' => 'guid1', 'type' => 'tcp' }),
                                                                       RoutingApi::RouterGroup.new({ 'guid' => 'guid2', 'type' => 'http' })])
    end

    describe 'transform' do
      context 'when the Routing API is not configured' do
        let(:router_group_type_populator) { RouterGroupTypePopulator.new(nil) }

        it 'returns domains without router group type' do
          router_group_type_populator.transform(domains)
          expect(domain1.router_group_types).to be_nil
          expect(domain2.router_group_types).to be_nil
          expect(domain3.router_group_types).to be_nil
          expect(domain4.router_group_types).to be_nil
        end
      end

      it 'populates domains with router group types from Routing API' do
        router_group_type_populator.transform(domains)
        expect(domain1.router_group_types).to eq(['tcp'])
        expect(domain2.router_group_types).to eq(['http'])
        expect(domain3.router_group_types).to be_nil
        expect(domain4.router_group_types).to be_nil
      end
    end
  end
end
