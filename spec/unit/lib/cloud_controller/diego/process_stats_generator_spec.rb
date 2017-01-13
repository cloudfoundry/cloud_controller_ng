require 'spec_helper'
require 'cloud_controller/diego/process_stats_generator'

module VCAP::CloudController
  module Diego
    RSpec.describe ProcessStatsGenerator do
      subject(:generator) { ProcessStatsGenerator.new }
      let(:bbs_instances_client) { instance_double(BbsInstancesClient) }

      before do
        CloudController::DependencyLocator.instance.register(:bbs_instances_client, bbs_instances_client)
        allow(bbs_instances_client).to receive(:lrp_instances).and_return(bbs_response)
      end

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

      describe '#bulk_generate' do
        let(:bbs_response) { [make_actual_lrp('instance-guid', 1, 'UNCLAIMED', '', 1.day.ago.to_i)] }

        let(:process1) { VCAP::CloudController::AppFactory.make }
        let(:process2) { VCAP::CloudController::AppFactory.make }
        before do
          allow(bbs_instances_client).to receive(:lrp_instances).and_return(bbs_response)
        end

        it 'sends lrp instance requests to diego in bulk' do
          generator.bulk_generate([process1, process2])
          expect(bbs_instances_client).to have_received(:lrp_instances).with(process1).exactly(:once)
          expect(bbs_instances_client).to have_received(:lrp_instances).with(process2).exactly(:once)
          expect(bbs_instances_client).to have_received(:lrp_instances).exactly(:twice)
        end
      end

      describe '#generate' do
        let(:bbs_response) do
          [
            make_actual_lrp(instance_guid, 1, 'UNCLAIMED', nil, yesterday),
            make_actual_lrp(instance_guid, 2, 'CLAIMED', nil, yesterday),
            make_actual_lrp(instance_guid, 3, 'RUNNING', nil, yesterday),
            make_actual_lrp(instance_guid, 4, 'CRASHED', 'instance-details', yesterday)
          ]
        end
        let(:process) { VCAP::CloudController::AppFactory.make }
        let(:process_guid) { ProcessGuid.from_process(process) }
        let(:instance_guid) { 'instance_guid' }
        let(:yesterday) { 1.day.ago.to_i }
        let(:seconds_since_yesterday) { 3600 * 24 }

        it 'returns stats' do
          Timecop.freeze do
            instances = generator.generate(process)
            expect(instances.length).to eq(4)
            expect(instances).to match([
              { instance_guid: 'instance_guid', index: 1, since: yesterday, uptime: seconds_since_yesterday, state: 'UNCLAIMED' },
              { instance_guid: 'instance_guid', index: 2, since: yesterday, uptime: seconds_since_yesterday, state: 'CLAIMED' },
              { instance_guid: 'instance_guid', index: 3, since: yesterday, uptime: seconds_since_yesterday, state: 'RUNNING' },
              { instance_guid: 'instance_guid', index: 4, since: yesterday, uptime: seconds_since_yesterday, state: 'CRASHED', details: 'instance-details' },
            ])
          end
        end
      end
    end
  end
end
