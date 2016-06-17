require 'spec_helper'
require 'cloud_controller/routing_api/router_group'

module VCAP::CloudController::RoutingApi
  RSpec.describe RouterGroup do
    context 'reservable ports' do
      let(:router_group) { RouterGroup.new({
                                              'guid' => '896c4de9-7a93-4ae8-4643-0864a694ef51',
                                              'name' => 'default-tcp',
                                              'type' => 'tcp',
                                              'reservable_ports' => '1,2,3,25-26,5,8,13'
                                          })}
      let(:expected_ports) { [1, 2, 3, 5, 8, 13] + Array(25..26) }

      it 'returns an array of reservable ports' do
        expect(router_group.reservable_ports).to eq(expected_ports)
      end

      context 'when ranges overlap' do
        let(:expected_ports) { [3] + Array(5..15) + Array(25..26) }
        let(:router_group) { RouterGroup.new({
                                                 'guid' => '896c4de9-7a93-4ae8-4643-0864a694ef51',
                                                 'name' => 'default-tcp',
                                                 'type' => 'tcp',
                                                 'reservable_ports' => '5-15,10-15,3,25-26,5,8,13'
                                             })}

        it 'does not return duplicates' do
          expect(router_group.reservable_ports).to eq(expected_ports)
        end
      end

      context 'when there are no ranges' do
        let(:expected_ports) { [3] + Array(5..10) }
        let(:router_group) { RouterGroup.new({
                                                 'guid' => '896c4de9-7a93-4ae8-4643-0864a694ef51',
                                                 'name' => 'default-tcp',
                                                 'type' => 'tcp',
                                                 'reservable_ports' => '3,5,6,7,8,9,10'
                                             })}

        it 'returns the port array' do
          expect(router_group.reservable_ports).to eq(expected_ports)
        end
      end
    end
  end
end
