require 'spec_helper'

module VCAP::CloudController
  module Diego
    describe InstancesReporter do
      subject { described_class.new(diego_client) }
      let(:app) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED', instances: desired_instances) }
      let(:diego_client) { double(:diego_client) }
      let(:desired_instances) { 3 }
      let(:instances_to_return) {
        [
            {process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', since: 1},
            {process_guid: 'process-guid', instance_guid: 'instance-B', index: 1, state: 'RUNNING', since: 2},
            {process_guid: 'process-guid', instance_guid: 'instance-C', index: 1, state: 'CRASHED', since: 3},
            {process_guid: 'process-guid', instance_guid: 'instance-D', index: 2, state: 'RUNNING', since: 4},
            {process_guid: 'process-guid', instance_guid: 'instance-E', index: 2, state: 'STARTING', since: 5},
            {process_guid: 'process-guid', instance_guid: 'instance-F', index: 3, state: 'STARTING', since: 6},
            {process_guid: 'process-guid', instance_guid: 'instance-G', index: 4, state: 'CRASHED', since: 7},
        ]
      }

      before do
        allow(diego_client).to receive(:lrp_instances).and_return(instances_to_return)
      end

      describe '#all_instances_for_app' do
        it 'should return all instances reporting for the specified app within range of app.instances' do
          result = subject.all_instances_for_app(app)

          expect(diego_client).to have_received(:lrp_instances).with(app)
          expect(result).to eq(
                                {
                                    0 => { state: 'RUNNING', since: 1 },
                                    1 => { state: 'CRASHED', since: 3 },
                                    2 => { state: 'STARTING', since: 5 },
                                })
        end

        it 'returns DOWN instances for instances that tps does not report within range of app.instances' do
          app.instances = 7

          result = subject.all_instances_for_app(app)

          expect(diego_client).to have_received(:lrp_instances).with(app)
          expect(result.length).to eq(app.instances)
          expect(result[5][:state]).to eq('DOWN')
          expect(result[6][:state]).to eq('DOWN')
        end

        context "when diego is unavailable" do
          before do
            allow(diego_client).to receive(:lrp_instances).and_raise(Diego::Unavailable)
          end

          it "raises an InstancesUnavailable exception" do
            expect { subject.all_instances_for_app(app) }.to raise_error(Errors::InstancesUnavailable, /Diego/)
          end
        end
      end

      describe '#number_of_starting_and_running_instances_for_app' do
        context 'when the app is not started' do
          before do
            app.state = 'STOPPED'
          end

          it 'returns 0' do
            result = subject.number_of_starting_and_running_instances_for_app(app)

            expect(diego_client).not_to have_received(:lrp_instances)
            expect(result).to eq(0)
          end
        end

        context 'when the app is started' do
          before do
            app.state = 'STARTED'
          end

          let(:desired_instances) { 3 }

          context 'when a desired instance is missing' do
            let(:instances_to_return) {
              [
                  {process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-D', index: 2, state: 'STARTING', since: 4},
              ]
            }

            it 'returns the number of desired indices that have an instance in the running/starting state ' do
              result = subject.number_of_starting_and_running_instances_for_app(app)

              expect(diego_client).to have_received(:lrp_instances).with(app)
              expect(result).to eq(2)
            end
          end

          context 'when multiple instances are reporting as running/started at a desired index' do
            let(:instances_to_return) {
              [
                  {process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-B', index: 0, state: 'STARTING', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-C', index: 1, state: 'RUNNING', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-D', index: 2, state: 'STARTING', since: 4},
              ]
            }

            it 'returns the number of desired indices that have an instance in the running/starting state ' do
              result = subject.number_of_starting_and_running_instances_for_app(app)

              expect(diego_client).to have_received(:lrp_instances).with(app)
              expect(result).to eq(3)
            end
          end

          context 'when there are undesired instances that are running/starting' do
            let(:instances_to_return) {
              [
                  {process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-B', index: 1, state: 'RUNNING', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-C', index: 2, state: 'STARTING', since: 4},
                  {process_guid: 'process-guid', instance_guid: 'instance-D', index: 3, state: 'RUNNING', since: 1},
              ]
            }

            it 'returns the number of desired indices that have an instance in the running/starting state ' do
              result = subject.number_of_starting_and_running_instances_for_app(app)

              expect(diego_client).to have_received(:lrp_instances).with(app)
              expect(result).to eq(3)
            end
          end

          context 'when there are crashed instances at a desired index' do
            let(:instances_to_return) {
              [
                  {process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-B', index: 0, state: 'CRASHED', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-C', index: 1, state: 'CRASHED', since: 1},
                  {process_guid: 'process-guid', instance_guid: 'instance-D', index: 2, state: 'STARTING', since: 1},
              ]
            }

            it 'returns the number of desired indices that have an instance in the running/starting state ' do
              result = subject.number_of_starting_and_running_instances_for_app(app)

              expect(diego_client).to have_received(:lrp_instances).with(app)
              expect(result).to eq(2)
            end
          end

          context "when diego is unavailable" do
            before do
              allow(diego_client).to receive(:lrp_instances).and_raise(Diego::Unavailable)
            end

            it "raises an InstancesUnavailable exception" do
              expect {
                subject.number_of_starting_and_running_instances_for_app(app)
              }.to raise_error(Errors::InstancesUnavailable, /Diego/)
            end
          end
        end
      end

      describe '#number_of_starting_and_running_instances_for_apps' do
        let(:app1) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED', state: 'STARTED', instances: 2) }
        let(:app2) { AppFactory.make(package_hash: 'abc', package_state: 'STAGED', state: 'STARTED', instances: 5) }

        it 'returns a hash of app => instance count' do
          result = subject.number_of_starting_and_running_instances_for_apps([app1, app2])
          expect(result).to eq({ app1.guid => 2, app2.guid => 4 })
        end

        context "when diego is unavailable" do
          before do
            allow(diego_client).to receive(:lrp_instances).and_raise(Diego::Unavailable)
          end

          it "raises an InstancesUnavailable exception" do
            expect {
              subject.number_of_starting_and_running_instances_for_apps([app1, app2])
            }.to raise_error(Errors::InstancesUnavailable, /Diego/)
          end
        end
      end

      describe '#crashed_instances_for_app' do
        it 'returns an array of crashed instances' do
          result = subject.crashed_instances_for_app(app)

          expect(diego_client).to have_received(:lrp_instances).with(app)
          expect(result).to eq([
                                   { 'instance' => 'instance-C', 'since' => 3 },
                               ])
        end

        context "when diego is unavailable" do
          before do
            allow(diego_client).to receive(:lrp_instances).and_raise(Diego::Unavailable)
          end

          it "raises an InstancesUnavailable exception" do
            expect {
              subject.crashed_instances_for_app(app)
            }.to raise_error(Errors::InstancesUnavailable, /Diego/)
          end
        end
      end

      describe '#stats_for_app' do
        it 'stubs out stuff for now' do
          result = subject.stats_for_app(app)

          expect(result).to eq(
                                {
                                    0 => {
                                        'state' => 'RUNNING',
                                        'stats' => {
                                            'mem_quota'  => 0,
                                            'disk_quota' => 0,
                                            'usage'      => {
                                                'cpu'  => 0,
                                                'mem'  => 0,
                                                'disk' => 0,
                                            }
                                        }
                                    },
                                    1 => {
                                        'state' => 'CRASHED',
                                        'stats' => {
                                            'mem_quota'  => 0,
                                            'disk_quota' => 0,
                                            'usage'      => {
                                                'cpu'  => 0,
                                                'mem'  => 0,
                                                'disk' => 0,
                                            }
                                        }
                                    },
                                    2 => {
                                        'state' => 'STARTING',
                                        'stats' => {
                                            'mem_quota'  => 0,
                                            'disk_quota' => 0,
                                            'usage'      => {
                                                'cpu'  => 0,
                                                'mem'  => 0,
                                                'disk' => 0,
                                            }
                                        }
                                    }
                                })
        end

        it 'returns DOWN instances for instances that tps does not report within range of app.instances' do
          app.instances = 7

          result = subject.stats_for_app(app)

          expect(diego_client).to have_received(:lrp_instances).with(app)
          expect(result.length).to eq(app.instances)
          expect(result[5][:state]).to eq('DOWN')
          expect(result[6][:state]).to eq('DOWN')
        end

        context "when diego is unavailable" do
          before do
            allow(diego_client).to receive(:lrp_instances).and_raise(Diego::Unavailable)
          end

          it "raises an InstancesUnavailable exception" do
            expect {
              subject.stats_for_app(app)
            }.to raise_error(Errors::InstancesUnavailable, /Diego/)
          end
        end
      end
    end
  end
end
