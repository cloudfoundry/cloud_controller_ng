require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RouterGroupTypePopulator do
    describe 'transform' do
      let(:router_group_type_populator) { RouterGroupTypePopulator.new(RoutingApi::DisabledClient.new) }
      let(:domain1) { SharedDomain.new(name: '1', router_group_guid: 'guid1') }
      let(:domain2) { SharedDomain.new(name: '2', router_group_guid: 'guid2') }
      let(:domain3) { SharedDomain.new(name: '3', router_group_guid: nil) }
      let(:domain4) { SharedDomain.new(name: '4', router_group_guid: 'guid3') }
      let(:domain5) { SharedDomain.new(name: '5', router_group_guid: nil) }

      it 'returns domains with empty router group type' do
        router_group_type_populator.transform([domain1, domain2, domain3, domain4, domain5])
        expect(domain1.router_group_type).to be_nil
        expect(domain2.router_group_type).to be_nil
        expect(domain3.router_group_type).to be_nil
        expect(domain4.router_group_type).to be_nil
        expect(domain5.router_group_type).to be_nil
      end

      context 'when routing API is configured' do
        let(:routing_api_client) { double(RoutingApi::Client, enabled?: true) }
        let(:router_group_type_populator) { RouterGroupTypePopulator.new(routing_api_client) }

        before do
          allow(routing_api_client).to receive(:router_groups).and_return([RoutingApi::RouterGroup.new({ 'guid' => 'guid1', 'type' => 'tcp' }),
                                                                           RoutingApi::RouterGroup.new({ 'guid' => 'guid2', 'type' => 'http' })])
        end

        it 'populates domains with router group type from Routing API' do
          router_group_type_populator.transform([domain1, domain2, domain3, domain4, domain5])
          expect(domain1.router_group_type).to eq('tcp')
          expect(domain2.router_group_type).to eq('http')
          expect(domain3.router_group_type).to be_nil
          expect(domain4.router_group_type).to be_nil
          expect(domain5.router_group_type).to be_nil
        end

        context 'when there are no domains associated with router groups' do
          it 'should not call the Routing API' do
            expect(routing_api_client).to_not receive(:router_groups)
            router_group_type_populator.transform([domain3, domain5])
          end
        end
      end
    end
  end
end
