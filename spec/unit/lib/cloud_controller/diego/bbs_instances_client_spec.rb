require 'spec_helper'

module VCAP::CloudController::Diego
  RSpec.describe BbsInstancesClient do
    subject(:client) { BbsInstancesClient.new(bbs_client) }
    let(:bbs_client) { instance_double(::Diego::Client) }

    describe '#lrp_instances' do
      let(:bbs_response) { ::Diego::Bbs::Models::ActualLRPsResponse.new(actual_lrps:) }
      let(:actual_lrps) { [actual_lrp] }
      let(:actual_lrp) { ::Diego::Bbs::Models::ActualLRP.new(state: 'potato') }
      let(:process) { VCAP::CloudController::ProcessModelFactory.make }
      let(:process_guid) { ProcessGuid.from_process(process) }

      before do
        allow(bbs_client).to receive(:actual_lrps_by_process_guid).with(process_guid).and_return(bbs_response)
      end

      it 'sends the lrp instances request to diego' do
        client.lrp_instances(process)
        expect(bbs_client).to have_received(:actual_lrps_by_process_guid).with(process_guid)
      end

      context 'when a Diego error is thrown' do
        before do
          allow(bbs_client).to receive(:actual_lrps_by_process_guid).with(process_guid).and_raise(::Diego::Error.new('boom'))
        end

        it 're-raises with a CC Error' do
          expect do
            client.lrp_instances(process)
          end.to raise_error(CloudController::Errors::InstancesUnavailable, 'boom')
        end
      end

      context 'when the response contains an unknown error' do
        let(:bbs_response) do
          ::Diego::Bbs::Models::ActualLRPsResponse.new(error: ::Diego::Bbs::Models::Error.new(message: 'error-message'))
        end

        it 'raises' do
          expect do
            client.lrp_instances(process)
          end.to raise_error(CloudController::Errors::InstancesUnavailable, 'error-message')
        end
      end
    end

    describe '#actual_lrps_by_processes' do
      let(:processes) { [VCAP::CloudController::ProcessModelFactory.make] }
      let(:process_guids) { [ProcessGuid.from_process(processes[0])] }
      let(:actual_lrp) { ::Diego::Bbs::Models::ActualLRP.new(state: 'potato') }
      let(:actual_lrps) { [actual_lrp] }
      let(:bbs_response) { ::Diego::Bbs::Models::ActualLRPsByProcessGuidsResponse.new(actual_lrps:) }

      before do
        allow(bbs_client).to receive(:actual_lrps_by_process_guids).with(process_guids).and_return(bbs_response)
      end

      it 'sends the lrp instances py process_guids request to diego' do
        client.actual_lrps_by_processes(processes)
        expect(bbs_client).to have_received(:actual_lrps_by_process_guids).with(process_guids)
      end

      context 'when the list of processes is empty' do
        let(:processes) { [] }
        let(:process_guids) { [] }

        it 'returns an empty list and does not call diego' do
          expect(client.actual_lrps_by_processes(processes)).to eq([])
          expect(bbs_client).not_to have_received(:actual_lrps_by_process_guids)
        end
      end

      context 'when a Diego error is thrown' do
        before do
          allow(bbs_client).to receive(:actual_lrps_by_process_guids).with(process_guids).and_raise(::Diego::Error.new('boom'))
        end

        it 're-raises with a CC Error' do
          expect do
            client.actual_lrps_by_processes(processes)
          end.to raise_error(CloudController::Errors::InstancesUnavailable, 'boom')
        end
      end

      context 'when the response contains an unknown error' do
        let(:bbs_response) do
          ::Diego::Bbs::Models::ActualLRPsByProcessGuidsResponse.new(error: ::Diego::Bbs::Models::Error.new(message: 'error-message'))
        end

        it 'raises' do
          expect do
            client.actual_lrps_by_processes(processes)
          end.to raise_error(CloudController::Errors::InstancesUnavailable, 'error-message')
        end
      end
    end

    describe '#desired_lrp_instance' do
      let(:bbs_response) { ::Diego::Bbs::Models::DesiredLRPResponse.new(desired_lrp:) }
      let(:desired_lrp) { ::Diego::Bbs::Models::DesiredLRP.new(PlacementTags: ['bieber']) }
      let(:process) { VCAP::CloudController::ProcessModelFactory.make }
      let(:process_guid) { ProcessGuid.from_process(process) }

      before do
        allow(bbs_client).to receive(:desired_lrp_by_process_guid).with(process_guid).and_return(bbs_response)
      end

      it 'sends the lrp instances request to diego' do
        client.desired_lrp_instance(process)
        expect(bbs_client).to have_received(:desired_lrp_by_process_guid).with(process_guid)
      end

      it 'returns the desired LRP' do
        resolved_desired_lrp = ::Diego::Bbs::Models::DesiredLRP.new(PlacementTags: ['bieber'])
        expect(client.desired_lrp_instance(process)).to eq(resolved_desired_lrp)
      end

      context 'when the response contains a ResourceNotFound error' do
        let(:bbs_response) do
          ::Diego::Bbs::Models::DesiredLRPResponse.new(error: ::Diego::Bbs::Models::Error.new(
            message: 'error-message',
            type: ::Diego::Bbs::Models::Error::Type::ResourceNotFound
          ))
        end

        it 'raises' do
          expect do
            client.desired_lrp_instance(process)
          end.to raise_error(CloudController::Errors::NoRunningInstances)
        end
      end

      context 'when a Diego error is thrown' do
        before do
          allow(bbs_client).to receive(:desired_lrp_by_process_guid).with(process_guid).and_raise(::Diego::Error.new('boom'))
        end

        it 're-raises with a CC Error' do
          expect do
            client.desired_lrp_instance(process)
          end.to raise_error(CloudController::Errors::InstancesUnavailable, 'boom')
        end
      end

      context 'when the response contains an unknown error' do
        let(:bbs_response) do
          ::Diego::Bbs::Models::DesiredLRPResponse.new(error: ::Diego::Bbs::Models::Error.new(message: 'error-message'))
        end

        it 'raises' do
          expect do
            client.desired_lrp_instance(process)
          end.to raise_error(CloudController::Errors::InstancesUnavailable, 'error-message')
        end
      end
    end
  end
end
