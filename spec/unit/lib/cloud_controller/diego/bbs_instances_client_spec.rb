require 'spec_helper'

module VCAP::CloudController::Diego
  RSpec.describe BbsInstancesClient do
    subject(:client) { BbsInstancesClient.new(bbs_client) }
    let(:bbs_client) { instance_double(::Diego::Client) }

    def makeActualLRPGroup(process_guid, lrp_index, lrp_state, placement_error)
      instance = ::Diego::Bbs::Models::ActualLRP.new(
        actual_lrp_key:
          ::Diego::Bbs::Models::ActualLRPKey.new({process_guid: process_guid, index: lrp_index}),
        actual_lrp_instance_key:
          ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: instance_guid),
        placement_error: placement_error,
        state: lrp_state,
        since: yesterday,
        actual_lrp_net_info: actual_lrp_net_info1,
        )

      return ::Diego::Bbs::Models::ActualLRPGroup.new(instance: instance)
    end

    describe '#lrp_instances' do
      let(:bbs_response) { ::Diego::Bbs::Models::ActualLRPGroupsResponse.new(actual_lrp_groups: actual_lrp_groups, error: error) }
      let(:actual_lrp_groups) { [::Diego::Bbs::Models::ActualLRPGroup.new(instance: actual_lrp1 ) ] }
      let(:actual_lrp1)  { ::Diego::Bbs::Models::ActualLRP.new(
        actual_lrp_key: actual_lrp_key1,
        actual_lrp_instance_key: actual_lrp_instance_key1,
        actual_lrp_net_info: actual_lrp_net_info1
      )  }
      let(:actual_lrp_key1) { ::Diego::Bbs::Models::ActualLRPKey.new }
      let(:actual_lrp_instance_key1) { ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: instance_guid) }
      let(:actual_lrp_net_info1) { ::Diego::Bbs::Models::ActualLRPNetInfo.new(address: address, ports: ports) }
      let(:error) { nil }
      let(:process) { VCAP::CloudController::AppFactory.make }
      let(:process_guid) { ProcessGuid.from_process(process) }
      let(:instance_guid) { 'instance_guid' }
      let(:yesterday) { 1.day.ago.to_i }
      let(:seconds_since_yesterday) { 3600 * 24 }
      let(:address)  { '1.2.3.4' }
      let(:ports) { [::Diego::Bbs::Models::PortMapping.new(container_port:5566, host_port:80) ] }

      before do
        allow(bbs_client).to receive(:actual_lrp_groups_by_process_guid).with(process_guid).and_return(bbs_response)
      end

      it 'sends the lrp instances request to diego' do
        client.lrp_instances(process)
        expect(bbs_client).to have_received(:actual_lrp_groups_by_process_guid).with(process_guid)
      end

      context 'when it successfully fetches the lrp instances' do
        let(:bbs_response) { ::Diego::Bbs::Models::ActualLRPGroupsResponse.new(actual_lrp_groups: actual_lrp_groups, error: error) }
        let(:actual_lrp_groups) {[
          makeActualLRPGroup(process_guid, 1, 'UNCLAIMED', ''),
          makeActualLRPGroup(process_guid, 2, 'CLAIMED', ''),
          makeActualLRPGroup(process_guid, 3, 'RUNNING', ''),
          makeActualLRPGroup(process_guid, 4, 'CRASHED', 'i crashed')
        ]}

        before do
          allow(bbs_client).to receive(:actual_lrp_groups_by_process_guid).with(process_guid).and_return(bbs_response)
        end

        it 'returns a list of instances' do
          instances = client.lrp_instances(process)
          expect(instances.length).to eq(4)
          expect(instances).to match([
           {
             process_guid: process_guid,
             instance_guid: 'instance_guid',
             index: 1,
             since: yesterday,
             uptime: seconds_since_yesterday,
             state: 'UNCLAIMED',
             net_info: actual_lrp_net_info1,
           },
           {
             process_guid: process_guid,
             instance_guid: 'instance_guid',
             index: 2,
             since: yesterday,
             uptime: seconds_since_yesterday,
             state: 'CLAIMED',
             net_info: actual_lrp_net_info1,
           },
           {
             process_guid: process_guid,
             instance_guid: 'instance_guid',
             index: 3,
             since: yesterday,
             uptime: seconds_since_yesterday,
             state: 'RUNNING',
             net_info: actual_lrp_net_info1,
           },
           {
             process_guid: process_guid,
             instance_guid: 'instance_guid',
             index: 4,
             since: yesterday,
             uptime: seconds_since_yesterday,
             state: 'CRASHED',
             net_info: actual_lrp_net_info1,
           },
          ])
        end
      end
    end

  end
end
