require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe InstancesReporter do
      subject(:instances_reporter) { InstancesReporter.new(bbs_instances_client) }

      let(:process) { ProcessModelFactory.make(instances: desired_instances) }
      let(:desired_instances) { 1 }
      let(:bbs_instances_client) { instance_double(BbsInstancesClient) }

      let(:two_days_ago_since_epoch_seconds) { 2.days.ago.to_i }
      let(:two_days_ago_since_epoch_ns) { 2.days.ago.to_f * 1e9 }
      let(:two_days_in_seconds) { 60 * 60 * 24 * 2 }

      def make_actual_lrp(instance_guid:, index:, state:, error:, since:)
        ::Diego::Bbs::Models::ActualLRP.new(
          actual_lrp_key:          ::Diego::Bbs::Models::ActualLRPKey.new(index: index),
          actual_lrp_instance_key: ::Diego::Bbs::Models::ActualLRPInstanceKey.new(instance_guid: instance_guid),
          state:                   state,
          placement_error:         error,
          since:                   since,
        )
      end

      before { Timecop.freeze(Time.at(1.day.ago.to_i)) }
      after { Timecop.return }

      describe '#crashed_instances_for_app' do
        let(:desired_instances) { bbs_instances_response.length }
        let(:bbs_instances_response) do
          [
            make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CRASHED, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-c', index: 2, state: ::Diego::ActualLRPState::UNCLAIMED, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-d', index: 3, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-e', index: 4, state: ::Diego::ActualLRPState::CRASHED, error: '', since: two_days_ago_since_epoch_ns),
          ]
        end

        before do
          allow(bbs_instances_client).to receive(:lrp_instances).with(process).and_return(bbs_instances_response)
        end

        it 'returns an array of crashed instances' do
          result = instances_reporter.crashed_instances_for_app(process)
          expect(result).to match_array(
            [
              { 'instance' => 'instance-b', 'uptime' => 0, 'since' => two_days_ago_since_epoch_seconds },
              { 'instance' => 'instance-e', 'uptime' => 0, 'since' => two_days_ago_since_epoch_seconds },
            ]
          )
        end

        it 'always sets uptime to 0 for crashed instances' do
          result  = instances_reporter.crashed_instances_for_app(process)
          uptimes = result.map { |i| i['uptime'] }

          expect(uptimes.all? { |i| i == 0 }).to be_truthy
        end

        it 'reports since as seconds' do
          result = instances_reporter.crashed_instances_for_app(process)
          sinces = result.map { |i| i['since'] }

          expect(sinces.all? { |i| i == two_days_ago_since_epoch_seconds }).to be_truthy
        end

        context 'when the bbs response contains more lrps than the process is configured for' do
          let(:process) { ProcessModelFactory.make(instances: 3) }

          it 'does not include the instances whose index is larger than the desired instances on the process' do
            result    = instances_reporter.crashed_instances_for_app(process)
            instances = result.map { |i| i['instance'] }

            expect(instances).to eq(['instance-b'])
          end
        end

        context 'when an error is thrown' do
          let(:error) { StandardError.new('potato') }

          before do
            allow(bbs_instances_client).to receive(:lrp_instances).with(process).and_raise(error)
          end

          it 'raises an InstancesUnavailable exception' do
            expect {
              instances_reporter.crashed_instances_for_app(process)
            }.to raise_error(CloudController::Errors::InstancesUnavailable, /potato/)
          end

          context 'when an InstancesUnavailable error is thrown' do
            let(:error) { CloudController::Errors::InstancesUnavailable.new('potato') }

            it 're-raises' do
              expect {
                instances_reporter.crashed_instances_for_app(process)
              }.to raise_error(error)
            end
          end
        end
      end

      describe '#number_of_starting_and_running_instances_for_process' do
        context 'when the app is not started' do
          before do
            process.state = 'STOPPED'
            allow(bbs_instances_client).to receive(:lrp_instances)
          end

          it 'returns 0' do
            expect(instances_reporter.number_of_starting_and_running_instances_for_process(process)).to eq(0)
            expect(bbs_instances_client).not_to have_received(:lrp_instances)
          end
        end

        context 'when the app is started' do
          let(:desired_instances) { bbs_instances_response.length }
          let(:bbs_instances_response) do
            [
              make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-d', index: 3, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-e', index: 4, state: ::Diego::ActualLRPState::CRASHED, error: '', since: two_days_ago_since_epoch_ns),
            ]
          end

          before do
            allow(bbs_instances_client).to receive(:lrp_instances).and_return(bbs_instances_response)
            process.state = 'STARTED'
          end

          it 'returns the number of instances that are in the running/started state' do
            expect(instances_reporter.number_of_starting_and_running_instances_for_process(process)).to eq(3)
          end

          context '"UNCLAIMED" instances' do
            let(:bbs_instances_response) do
              [
                make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::UNCLAIMED, error: 'error-present', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::UNCLAIMED, error: '', since: two_days_ago_since_epoch_ns),
              ]
            end

            it 'counts UNCLAIMED as starting and UNCLAIMED with placement_error as down' do
              expect(instances_reporter.number_of_starting_and_running_instances_for_process(process)).to eq(1)
            end
          end

          context 'when multiple instances are reported as running/started at the same index' do
            let(:bbs_instances_response) do
              [
                make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-c', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-d', index: 1, state: ::Diego::ActualLRPState::CRASHED, error: '', since: two_days_ago_since_epoch_ns),
              ]
            end

            it 'ignores duplicates' do
              expect(instances_reporter.number_of_starting_and_running_instances_for_process(process)).to eq(2)
            end
          end

          context 'when a desired instance is missing' do
            let(:desired_instances) { 3 }
            let(:bbs_instances_response) do
              [
                make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-c', index: 2, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
              ]
            end

            it 'ignores the missing one' do
              expect(instances_reporter.number_of_starting_and_running_instances_for_process(process)).to eq(2)
            end
          end

          context 'when the bbs response contains more lrps than the process is configured for' do
            let(:desired_instances) { 3 }
            let(:bbs_instances_response) do
              [
                make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-c', index: 2, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-d', index: 3, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
                make_actual_lrp(instance_guid: 'instance-e', index: 4, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
              ]
            end

            it 'does not include the instances whose index is larger than the desired instances on the process' do
              expect(instances_reporter.number_of_starting_and_running_instances_for_process(process)).to eq(3)
            end
          end
        end

        context 'when an error is thrown' do
          before do
            process.state = 'STARTED'
            allow(bbs_instances_client).to receive(:lrp_instances).and_raise(StandardError.new('potato'))
          end

          it 'returns -1' do
            expect(instances_reporter.number_of_starting_and_running_instances_for_process(process)).to eq(-1)
          end
        end
      end

      describe '#number_of_starting_and_running_instances_for_processes' do
        let(:process_a) { ProcessModelFactory.make(instances: bbs_instances_response_a.length) }
        let(:process_b) { ProcessModelFactory.make(instances: 3) }
        let(:process_c) { ProcessModelFactory.make(instances: bbs_instances_response_c.length) }

        let(:bbs_instances_response_a) do
          [
            make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-d', index: 2, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-e', index: 3, state: ::Diego::ActualLRPState::CRASHED, error: '', since: two_days_ago_since_epoch_ns),
          ]
        end
        let(:bbs_instances_response_c) do
          [
            make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-d', index: 2, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
          ]
        end

        before do
          allow(bbs_instances_client)
          process_b.state = 'STOPPED'
          process_a.state = 'STARTED'
          process_c.state = 'STARTED'

          allow(bbs_instances_client).to receive(:lrp_instances).with(process_a).and_return(bbs_instances_response_a)
          allow(bbs_instances_client).to receive(:lrp_instances).with(process_c).and_return(bbs_instances_response_c)
        end

        it 'calculates the number of starting/running instances for each process' do
          expect(instances_reporter.number_of_starting_and_running_instances_for_processes([process_a, process_b, process_c])).to eq(
            {
              process_a.guid => 3,
              process_b.guid => 0,
              process_c.guid => 3,
            }
          )
        end

        it 'does not fetch lrp status for stopped apps' do
          allow(bbs_instances_client).to receive(:lrp_instances).with(process_b)
          instances_reporter.number_of_starting_and_running_instances_for_processes([process_a, process_b, process_c])

          expect(bbs_instances_client).not_to have_received(:lrp_instances).with(process_b)
        end

        it 'does not instantiate multiple WorkPools' do
          expect(WorkPool).to receive(:new).at_most(:once).and_call_original

          instances_reporter.number_of_starting_and_running_instances_for_processes([process_a, process_b, process_c])
          instances_reporter.number_of_starting_and_running_instances_for_processes([process_a, process_b, process_c])
        end

        it 'replenishes the workpool' do
          allow(InstancesReporter.singleton_workpool).to receive(:replenish)
          instances_reporter.number_of_starting_and_running_instances_for_processes([process_a, process_b, process_c])
          instances_reporter.number_of_starting_and_running_instances_for_processes([process_a, process_b, process_c])
          expect(InstancesReporter.singleton_workpool).to have_received(:replenish).twice
        end

        context '"UNCLAIMED" instances' do
          let(:bbs_instances_response_a) do
            [
              make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::UNCLAIMED, error: 'error-present', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::UNCLAIMED, error: '', since: two_days_ago_since_epoch_ns),
            ]
          end

          it 'counts UNCLAIMED as starting and UNCLAIMED with placement_error as down' do
            expect(instances_reporter.number_of_starting_and_running_instances_for_processes([process_a])).to eq({ process_a.guid => 1 })
          end
        end

        context 'when multiple instances are reported as running/started at the same index' do
          let(:bbs_instances_response_a) do
            [
              make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-c', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-d', index: 1, state: ::Diego::ActualLRPState::CRASHED, error: '', since: two_days_ago_since_epoch_ns),
            ]
          end

          it 'ignores duplicates' do
            expect(instances_reporter.number_of_starting_and_running_instances_for_processes([process_a])).to eq({ process_a.guid => 2 })
          end
        end

        context 'when a desired instance is missing' do
          let(:process_a) { ProcessModelFactory.make(instances: 3) }
          let(:bbs_instances_response_a) do
            [
              make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-c', index: 2, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
            ]
          end

          it 'ignores the missing one' do
            expect(instances_reporter.number_of_starting_and_running_instances_for_processes([process_a])).to eq({ process_a.guid => 2 })
          end
        end

        context 'when the bbs response contains more lrps than the process is configured for' do
          let(:process_a) { ProcessModelFactory.make(instances: 3) }
          let(:bbs_instances_response_a) do
            [
              make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-c', index: 2, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-d', index: 3, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-e', index: 4, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
            ]
          end

          it 'does not include the instances whose index is larger than the desired instances on the process' do
            expect(instances_reporter.number_of_starting_and_running_instances_for_processes([process_a])).to eq({ process_a.guid => 3 })
          end
        end

        context 'when an error is thrown for one of the processes' do
          before do
            allow(bbs_instances_client).to receive(:lrp_instances).with(process_a).and_raise(StandardError.new('potato'))
          end

          it 'returns -1 for that process' do
            expect(instances_reporter.number_of_starting_and_running_instances_for_processes([process_a, process_b, process_c])).to eq(
              {
                process_a.guid => -1,
                process_b.guid => 0,
                process_c.guid => 3,
              }
            )
          end
        end
      end

      describe '#all_instances_for_app' do
        let(:desired_instances) { bbs_instances_response.length }
        let(:bbs_instances_response) do
          [
            make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::CLAIMED, error: '', since: two_days_ago_since_epoch_ns),
            make_actual_lrp(instance_guid: 'instance-c', index: 2, state: ::Diego::ActualLRPState::CRASHED, error: '', since: two_days_ago_since_epoch_ns),
          ]
        end

        before do
          allow(bbs_instances_client).to receive(:lrp_instances).and_return(bbs_instances_response)
        end

        it 'reports on all instances for the provided process' do
          expect(instances_reporter.all_instances_for_app(process)).to eq(
            {
              0 => { state: 'RUNNING', uptime: two_days_in_seconds, since: two_days_ago_since_epoch_seconds },
              1 => { state: 'STARTING', uptime: two_days_in_seconds, since: two_days_ago_since_epoch_seconds },
              2 => { state: 'CRASHED', uptime: two_days_in_seconds, since: two_days_ago_since_epoch_seconds },
            }
          )
        end

        context 'when the state is "UNCLAIMED"' do
          context 'and there is no error' do
            let(:bbs_instances_response) do
              [make_actual_lrp(instance_guid: 'instance-d', index: 0, state: ::Diego::ActualLRPState::UNCLAIMED, error: '', since: two_days_ago_since_epoch_ns)]
            end

            it 'report the instance as "STARTED"' do
              expect(instances_reporter.all_instances_for_app(process)).to eq(
                { 0 => { state: 'STARTING', uptime: two_days_in_seconds, since: two_days_ago_since_epoch_seconds } }
              )
            end
          end

          context 'and there is an error' do
            let(:bbs_instances_response) do
              [make_actual_lrp(instance_guid: 'instance-d', index: 0, state: ::Diego::ActualLRPState::UNCLAIMED, error: 'some-error', since: two_days_ago_since_epoch_ns),]
            end

            it 'report the instance as "DOWN"' do
              expect(instances_reporter.all_instances_for_app(process)).to eq(
                { 0 => { state: 'DOWN', details: 'some-error', uptime: two_days_in_seconds, since: two_days_ago_since_epoch_seconds } }
              )
            end
          end
        end

        context 'when a desired instance is missing' do
          let(:desired_instances) { 3 }
          let(:bbs_instances_response) do
            [
              make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-c', index: 2, state: ::Diego::ActualLRPState::CRASHED, error: '', since: two_days_ago_since_epoch_ns),
            ]
          end

          it 'reports the instance as "DOWN"' do
            expect(instances_reporter.all_instances_for_app(process)).to eq(
              {
                0 => { state: 'RUNNING', uptime: two_days_in_seconds, since: two_days_ago_since_epoch_seconds },
                1 => { state: 'DOWN', uptime: 0 },
                2 => { state: 'CRASHED', uptime: two_days_in_seconds, since: two_days_ago_since_epoch_seconds },
              }
            )
          end
        end

        context 'when the bbs response contains more lrps than the process is configured for' do
          let(:desired_instances) { 1 }
          let(:bbs_instances_response) do
            [
              make_actual_lrp(instance_guid: 'instance-a', index: 0, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
              make_actual_lrp(instance_guid: 'instance-b', index: 1, state: ::Diego::ActualLRPState::RUNNING, error: '', since: two_days_ago_since_epoch_ns),
            ]
          end

          it 'ignores the superfluous instances' do
            expect(instances_reporter.all_instances_for_app(process)).to eq(
              {
                0 => { state: 'RUNNING', uptime: two_days_in_seconds, since: two_days_ago_since_epoch_seconds },
              }
            )
          end
        end

        context 'when an error is raised' do
          let(:error) { StandardError.new('tomato') }
          before do
            allow(bbs_instances_client).to receive(:lrp_instances).with(process).and_raise(error)
          end

          it 'raises an InstancesUnavailable exception' do
            expect { instances_reporter.all_instances_for_app(process) }.to raise_error(CloudController::Errors::InstancesUnavailable, /tomato/)
          end

          context 'when the error is InstancesUnavailable' do
            let(:error) { CloudController::Errors::InstancesUnavailable.new('ruh roh') }

            it 'reraises the exception' do
              expect { instances_reporter.all_instances_for_app(process) }.to raise_error(CloudController::Errors::InstancesUnavailable, /ruh roh/)
            end
          end
        end
      end
    end
  end
end
