require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe InstancesReporter do
      subject { described_class.new(tps_client) }
      let(:app) { AppFactory.make(instances: desired_instances, memory: 128, disk_quota: 2048) }
      let(:tps_client) { double(:tps_client) }
      let(:desired_instances) { 3 }
      let(:now) { Time.now.utc }
      let(:usage_time) { now.to_s }
      let(:instances_to_return) {
        [
          {
            process_guid: 'process-guid',
            instance_guid: 'instance-A',
            index: 0,
            state: 'RUNNING',
            details: 'some-details',
            uptime: 1,
            since: 101,
            host: 'myhost',
            port: 8080,
            net_info: { foo: 'ports-A' },
            stats: { time: usage_time, cpu: 80, mem: 128, disk: 1024 }
          },
          { process_guid: 'process-guid', instance_guid: 'instance-B', index: 1, state: 'RUNNING', uptime: 2, since: 202, host: 'myhost1', port: 8081,
            net_info: { foo: 'ports-B' }, stats: { time: usage_time, cpu: 70, mem: 128, disk: 1024 } },
          { process_guid: 'process-guid', instance_guid: 'instance-C', index: 1, state: 'CRASHED', uptime: 3, since: 303, host: 'myhost1', port: 8081,
            net_info: { foo: 'ports-C' }, stats: { time: usage_time, cpu: 70, mem: 128, disk: 1024 } },
          { process_guid: 'process-guid', instance_guid: 'instance-D', index: 2, state: 'RUNNING', uptime: 4, since: 404, host: 'myhost2', port: 8082,
            net_info: { foo: 'ports-D' }, stats: { time: usage_time, cpu: 80, mem: 256, disk: 1024 } },
          { process_guid: 'process-guid', instance_guid: 'instance-E', index: 2, state: 'STARTING', uptime: 5, since: 505, host: 'myhost2', port: 8082,
            net_info: { foo: 'ports-E' }, stats: { time: usage_time, cpu: 80, mem: 256, disk: 1024 } },
          { process_guid: 'process-guid', instance_guid: 'instance-F', index: 3, state: 'STARTING', uptime: 6, since: 606, host: 'myhost3', port: 8083,
            net_info: { foo: 'ports-F' }, stats: { time: usage_time, cpu: 80, mem: 128, disk: 1024 } },
          { process_guid: 'process-guid', instance_guid: 'instance-G', index: 4, state: 'CRASHED', uptime: 7, since: 707, host: 'myhost4', port: 8084,
            net_info: { foo: 'ports-G' }, stats: { time: usage_time, cpu: 80, mem: 128, disk: 1024 } },
        ]
      }

      before do
        allow(tps_client).to receive(:lrp_instances).and_return(instances_to_return)
        allow(tps_client).to receive(:lrp_instances_stats).and_return(instances_to_return)
      end

      describe '#all_instances_for_app' do
        it 'should return all instances reporting for the specified app within range of app.instances' do
          result = subject.all_instances_for_app(app)

          expect(tps_client).to have_received(:lrp_instances).with(app)
          expect(result).to eq(
            {
              0 => { state: 'RUNNING', details: 'some-details', uptime: 1, since: 101 },
              1 => { state: 'CRASHED', uptime: 3, since: 303 },
              2 => { state: 'STARTING', uptime: 5, since: 505 },
            })
        end

        it 'returns DOWN instances for instances that tps does not report within range of app.instances' do
          app.instances = 7

          result = subject.all_instances_for_app(app)

          expect(tps_client).to have_received(:lrp_instances).with(app)
          expect(result.length).to eq(app.instances)
          expect(result[5][:state]).to eq('DOWN')
          expect(result[6][:state]).to eq('DOWN')
        end

        context 'when an error is raised' do
          before do
            allow(tps_client).to receive(:lrp_instances).and_raise(StandardError.new('oh no'))
          end

          it 'raises an InstancesUnavailable exception' do
            expect { subject.all_instances_for_app(app) }.to raise_error(CloudController::Errors::InstancesUnavailable, /oh no/)
          end

          context 'when its an InstancesUnavailable' do
            let(:error) { CloudController::Errors::InstancesUnavailable.new('oh my') }
            before do
              allow(tps_client).to receive(:lrp_instances).and_raise(error)
            end

            it 're-raises' do
              expect { subject.all_instances_for_app(app) }.to raise_error(error)
            end
          end
        end
      end

      describe '#number_of_starting_and_running_instances_for_process' do
        context 'when the app is not started' do
          before do
            app.state = 'STOPPED'
          end

          it 'returns 0' do
            result = subject.number_of_starting_and_running_instances_for_process(app)

            expect(tps_client).not_to have_received(:lrp_instances)
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
                { process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', uptime: 1, since: 101 },
                { process_guid: 'process-guid', instance_guid: 'instance-D', index: 2, state: 'STARTING', uptime: 4, since: 404 },
              ]
            }

            it 'returns the number of desired indices that have an instance in the running/starting state ' do
              result = subject.number_of_starting_and_running_instances_for_process(app)

              expect(tps_client).to have_received(:lrp_instances).with(app)
              expect(result).to eq(2)
            end
          end

          context 'when multiple instances are reporting as running/started at a desired index' do
            let(:instances_to_return) {
              [
                { process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', uptime: 1 },
                { process_guid: 'process-guid', instance_guid: 'instance-B', index: 0, state: 'STARTING', uptime: 1 },
                { process_guid: 'process-guid', instance_guid: 'instance-C', index: 1, state: 'RUNNING', uptime: 1 },
                { process_guid: 'process-guid', instance_guid: 'instance-D', index: 2, state: 'STARTING', uptime: 4 },
              ]
            }

            it 'returns the number of desired indices that have an instance in the running/starting state ' do
              result = subject.number_of_starting_and_running_instances_for_process(app)

              expect(tps_client).to have_received(:lrp_instances).with(app)
              expect(result).to eq(3)
            end
          end

          context 'when there are undesired instances that are running/starting' do
            let(:instances_to_return) {
              [
                { process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', uptime: 1 },
                { process_guid: 'process-guid', instance_guid: 'instance-B', index: 1, state: 'RUNNING', uptime: 1 },
                { process_guid: 'process-guid', instance_guid: 'instance-C', index: 2, state: 'STARTING', uptime: 4 },
                { process_guid: 'process-guid', instance_guid: 'instance-D', index: 3, state: 'RUNNING', uptime: 1 },
              ]
            }

            it 'returns the number of desired indices that have an instance in the running/starting state ' do
              result = subject.number_of_starting_and_running_instances_for_process(app)

              expect(tps_client).to have_received(:lrp_instances).with(app)
              expect(result).to eq(3)
            end
          end

          context 'when there are crashed instances at a desired index' do
            let(:instances_to_return) {
              [
                { process_guid: 'process-guid', instance_guid: 'instance-A', index: 0, state: 'RUNNING', uptime: 1 },
                { process_guid: 'process-guid', instance_guid: 'instance-B', index: 0, state: 'CRASHED', uptime: 1 },
                { process_guid: 'process-guid', instance_guid: 'instance-C', index: 1, state: 'CRASHED', uptime: 1 },
                { process_guid: 'process-guid', instance_guid: 'instance-D', index: 2, state: 'STARTING', uptime: 1 },
              ]
            }

            it 'returns the number of desired indices that have an instance in the running/starting state ' do
              result = subject.number_of_starting_and_running_instances_for_process(app)

              expect(tps_client).to have_received(:lrp_instances).with(app)
              expect(result).to eq(2)
            end
          end

          context 'when diego is unavailable' do
            before do
              allow(tps_client).to receive(:lrp_instances).and_raise(StandardError.new('oh no'))
            end

            it 'returns -1 indicating not fresh' do
              expect(subject.number_of_starting_and_running_instances_for_process(app)).to eq(-1)
            end

            context 'when its an InstancesUnavailable' do
              let(:error) { CloudController::Errors::InstancesUnavailable.new('oh my') }
              before do
                allow(tps_client).to receive(:lrp_instances).and_raise(error)
              end

              it 'returns -1 indicating not fresh' do
                expect(subject.number_of_starting_and_running_instances_for_process(app)).to eq(-1)
              end
            end
          end
        end
      end

      describe '#number_of_starting_and_running_instances_for_processes' do
        let(:app1) { AppFactory.make(state: 'STARTED', instances: 2) }
        let(:app2) { AppFactory.make(state: 'STARTED', instances: 5) }
        let(:instance_map) do
          {
            app1.guid => [
              {
                state: 'RUNNING',
                index: 0
              },
              {
                state: 'STARTING',
                index: 1
              },
              {
                state: 'CRASHED',
                index: 2
              },
              {
                state: 'STARTING',
                index: 1
              },
            ],
            app2.guid => [
              {
                state: 'RUNNING',
                index: 0
              },
              {
                state: 'STARTING',
                index: 1
              },
              {
                state: 'CRASHED',
                index: 2
              },
              {
                state: 'RUNNING',
                index: 3
              }
            ],
          }
        end

        before do
          allow(tps_client).to receive(:bulk_lrp_instances).and_return(instance_map)
        end

        it 'returns a hash of app => instance count' do
          result = subject.number_of_starting_and_running_instances_for_processes([app1, app2])
          expect(result).to eq({ app1.guid => 2, app2.guid => 3 })
        end

        context 'when diego is unavailable' do
          before do
            allow(tps_client).to receive(:bulk_lrp_instances).and_raise(StandardError.new('oh no'))
          end

          it 'returns -1 indicating not fresh' do
            expect(subject.number_of_starting_and_running_instances_for_processes([app1, app2])).to eq({ app1.guid => -1, app2.guid => -1 })
          end

          context 'when its an InstancesUnavailable' do
            let(:error) { CloudController::Errors::InstancesUnavailable.new('oh my') }
            before do
              allow(tps_client).to receive(:bulk_lrp_instances).and_raise(error)
            end

            it 'returns -1 indicating not fresh' do
              expect(subject.number_of_starting_and_running_instances_for_processes([app1, app2])).to eq({ app1.guid => -1, app2.guid => -1 })
            end
          end
        end
      end

      describe '#crashed_instances_for_app' do
        it 'returns an array of crashed instances' do
          result = subject.crashed_instances_for_app(app)

          expect(tps_client).to have_received(:lrp_instances).with(app)
          expect(result).to eq([
            { 'instance' => 'instance-C', 'uptime' => 3, 'since' => 303 },
          ])
        end

        context 'when diego is unavailable' do
          before do
            allow(tps_client).to receive(:lrp_instances).and_raise(StandardError.new('oh no'))
          end

          it 'raises an InstancesUnavailable exception' do
            expect {
              subject.crashed_instances_for_app(app)
            }.to raise_error(CloudController::Errors::InstancesUnavailable, /oh no/)
          end

          context 'when its an InstancesUnavailable' do
            let(:error) { CloudController::Errors::InstancesUnavailable.new('oh my') }
            before do
              allow(tps_client).to receive(:lrp_instances).and_raise(error)
            end

            it 're-raises' do
              expect { subject.crashed_instances_for_app(app) }.to raise_error(error)
            end
          end
        end
      end

      describe '#stats_for_app' do
        it 'returns the stats reported for the application' do
          result = subject.stats_for_app(app)

          expect(result).to eq(
            {
              0 => {
                state:  'RUNNING',
                stats:  {
                  name:  app.name,
                  uris:  app.uris,
                  host:  'myhost',
                  port:  8080,
                  net_info:  { foo:  'ports-A' },
                  uptime:  instances_to_return[0][:uptime],
                  mem_quota:   app[:memory] * 1024 * 1024,
                  disk_quota:  app[:disk_quota] * 1024 * 1024,
                  fds_quota:  app.file_descriptors,
                  usage:  {
                    time:  usage_time,
                    cpu:   80,
                    mem:   128,
                    disk:  1024,
                  }
                },
                details:  'some-details',
              },
              1 => {
                state:  'CRASHED',
                stats:  {
                  name:  app.name,
                  uris:  app.uris,
                  host:  'myhost1',
                  port:  8081,
                  net_info:  { foo:  'ports-C' },
                  uptime:  instances_to_return[2][:uptime],
                  mem_quota:   app[:memory] * 1024 * 1024,
                  disk_quota:  app[:disk_quota] * 1024 * 1024,
                  fds_quota:  app.file_descriptors,
                  usage:  {
                    time:  usage_time,
                    cpu:   70,
                    mem:   128,
                    disk:  1024,
                  }
                }
              },
              2 => {
                state:  'STARTING',
                stats:  {
                  name:  app.name,
                  uris:  app.uris,
                  host:  'myhost2',
                  port:  8082,
                  net_info:  { foo:  'ports-E' },
                  uptime:  instances_to_return[4][:uptime],
                  mem_quota:   app[:memory] * 1024 * 1024,
                  disk_quota:  app[:disk_quota] * 1024 * 1024,
                  fds_quota:  app.file_descriptors,
                  usage:  {
                    time:  usage_time,
                    cpu:   80,
                    mem:   256,
                    disk:  1024,
                  }
                }
              }
            })
        end

        it 'returns DOWN instances for instances that tps does not report within range of app.instances' do
          app.instances = 7

          result = subject.stats_for_app(app)

          expect(tps_client).to have_received(:lrp_instances_stats).with(app)
          expect(result.length).to eq(app.instances)
          expect(result[5][:state]).to eq('DOWN')
          expect(result[6][:state]).to eq('DOWN')
        end

        context 'when no stats are returned for an instance' do
          before do
            instances_to_return[0].delete(:stats)
          end

          it 'creates zero usage for the instance' do
            allow(Time).to receive(:now).and_return(now)
            result = subject.stats_for_app(app)

            expect(result[0][:stats]).to eq({
              name: app.name,
              uris: app.uris,
              host: 'myhost',
              port: 8080,
              net_info: { foo: 'ports-A' },
              uptime: instances_to_return[0][:uptime],
              mem_quota:  app[:memory] * 1024 * 1024,
              disk_quota: app[:disk_quota] * 1024 * 1024,
              fds_quota: app.file_descriptors,
              usage: {
                time: usage_time,
                cpu:  0,
                mem:  0,
                disk: 0,
              }
            })
          end
        end

        context 'when diego is unavailable' do
          before do
            allow(tps_client).to receive(:lrp_instances_stats).and_raise(StandardError.new('oh no'))
          end

          it 'raises an InstancesUnavailable exception' do
            expect {
              subject.stats_for_app(app)
            }.to raise_error(CloudController::Errors::InstancesUnavailable, /oh no/)
          end

          context 'when its an InstancesUnavailable' do
            let(:error) { CloudController::Errors::InstancesUnavailable.new('oh my') }
            before do
              allow(tps_client).to receive(:lrp_instances_stats).and_raise(error)
            end

            it 're-raises' do
              expect { subject.stats_for_app(app) }.to raise_error(error)
            end
          end
        end
      end
    end
  end
end
