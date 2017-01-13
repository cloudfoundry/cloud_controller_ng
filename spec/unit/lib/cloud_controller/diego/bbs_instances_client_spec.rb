require 'spec_helper'

module VCAP::CloudController::Diego
  RSpec.describe BbsInstancesClient do
    subject(:client) { BbsInstancesClient.new(bbs_client) }
    let(:bbs_client) { instance_double(::Diego::Client) }

    def make_actual_lrp_group(instance_guid, lrp_index, lrp_state, placement_error, since)
      ::Diego::Bbs::Models::ActualLRPGroup.new(instance: make_actual_lrp(instance_guid, lrp_index, lrp_state, placement_error, since))
    end

    def make_actual_lrp(instance_guid, lrp_index, lrp_state, placement_error, since)
      ::Diego::Bbs::Models::ActualLRP.new(
        actual_lrp_key:          ::Diego::Bbs::Models::ActualLRPKey.new(index: lrp_index),
        actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: instance_guid),
        state:                   lrp_state,
        placement_error:         placement_error,
        since:                   since,
      )
    end

    describe '#bulk_lrp_instances' do
      let(:bbs_response) { ::Diego::Bbs::Models::ActualLRPGroupsResponse.new(actual_lrp_groups: actual_lrp_groups) }
      let(:actual_lrp_groups) { [make_actual_lrp_group('instance-guid', 1, 'UNCLAIMED', '', 1.day.ago.to_i)] }

      let(:process1) { VCAP::CloudController::AppFactory.make }
      let(:process2) { VCAP::CloudController::AppFactory.make }
      before do
        allow(bbs_client).to receive(:actual_lrp_groups_by_process_guid).with(instance_of(String)).and_return(bbs_response)
      end

      it 'sends lrp instance requests to diego in bulk' do
        client.bulk_lrp_instances([process1, process2])
        expect(bbs_client).to have_received(:actual_lrp_groups_by_process_guid).with(ProcessGuid.from_process(process1)).exactly(:once)
        expect(bbs_client).to have_received(:actual_lrp_groups_by_process_guid).with(ProcessGuid.from_process(process2)).exactly(:once)
        expect(bbs_client).to have_received(:actual_lrp_groups_by_process_guid).with(instance_of(String)).exactly(:twice)
      end
    end

    describe '#lrp_instances' do
      let(:bbs_response) { ::Diego::Bbs::Models::ActualLRPGroupsResponse.new(actual_lrp_groups: actual_lrp_groups) }
      let(:actual_lrp_groups) { [make_actual_lrp_group(instance_guid, 1, 'UNCLAIMED', '', yesterday)] }
      let(:process) { VCAP::CloudController::AppFactory.make }
      let(:process_guid) { ProcessGuid.from_process(process) }
      let(:instance_guid) { 'instance_guid' }
      let(:yesterday) { 1.day.ago.to_i }
      let(:seconds_since_yesterday) { 3600 * 24 }

      before do
        allow(bbs_client).to receive(:actual_lrp_groups_by_process_guid).with(process_guid).and_return(bbs_response)
      end

      it 'sends the lrp instances request to diego' do
        client.lrp_instances(process)
        expect(bbs_client).to have_received(:actual_lrp_groups_by_process_guid).with(process_guid)
      end

      context 'when it successfully fetches the lrp instances' do
        let(:actual_lrp_groups) do
          [
            make_actual_lrp_group(instance_guid, 1, 'UNCLAIMED', nil, yesterday),
            make_actual_lrp_group(instance_guid, 2, 'CLAIMED', nil, yesterday),
            make_actual_lrp_group(instance_guid, 3, 'RUNNING', nil, yesterday),
            make_actual_lrp_group(instance_guid, 4, 'CRASHED', 'instance-details', yesterday)
          ]
        end

        it 'returns a list of instances' do
          instances = client.lrp_instances(process)
          expect(instances.length).to eq(4)
          expect(instances).to match([
            { instance_guid: 'instance_guid', index: 1, since: yesterday, uptime: seconds_since_yesterday, state: 'UNCLAIMED' },
            { instance_guid: 'instance_guid', index: 2, since: yesterday, uptime: seconds_since_yesterday, state: 'CLAIMED' },
            { instance_guid: 'instance_guid', index: 3, since: yesterday, uptime: seconds_since_yesterday, state: 'RUNNING' },
            { instance_guid: 'instance_guid', index: 4, since: yesterday, uptime: seconds_since_yesterday, state: 'CRASHED', details: 'instance-details' },
          ])
        end
      end

      context 'when "instance" is not set on the actual lrp group' do
        let(:actual_lrp_groups) do
          [
            ::Diego::Bbs::Models::ActualLRPGroup.new(evacuating: make_actual_lrp(instance_guid, 1, 'UNCLAIMED', nil, yesterday)),
            ::Diego::Bbs::Models::ActualLRPGroup.new(evacuating: make_actual_lrp(instance_guid, 2, 'CLAIMED', nil, yesterday)),
            ::Diego::Bbs::Models::ActualLRPGroup.new(evacuating: make_actual_lrp(instance_guid, 3, 'RUNNING', nil, yesterday)),
            ::Diego::Bbs::Models::ActualLRPGroup.new(evacuating: make_actual_lrp(instance_guid, 4, 'CRASHED', 'instance-details', yesterday)),
          ]
        end
        it 'falls back to "evacuating"' do
          instances = client.lrp_instances(process)
          expect(instances.length).to eq(4)
          expect(instances).to match([
            { instance_guid: 'instance_guid', index: 1, since: yesterday, uptime: seconds_since_yesterday, state: 'UNCLAIMED' },
            { instance_guid: 'instance_guid', index: 2, since: yesterday, uptime: seconds_since_yesterday, state: 'CLAIMED' },
            { instance_guid: 'instance_guid', index: 3, since: yesterday, uptime: seconds_since_yesterday, state: 'RUNNING' },
            { instance_guid: 'instance_guid', index: 4, since: yesterday, uptime: seconds_since_yesterday, state: 'CRASHED', details: 'instance-details' },
          ])
        end
      end
      context 'when "instance" and "evacuating" are not set on the actual lrp group' do
        let(:actual_lrp_groups) { [::Diego::Bbs::Models::ActualLRPGroup.new] }
        it 'raises' do
          expect { client.lrp_instances(process) }.to raise_error(CloudController::Errors::InstancesUnavailable)
        end
      end
    end
  end
end
