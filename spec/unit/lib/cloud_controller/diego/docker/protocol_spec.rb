require 'spec_helper'
require 'cloud_controller/diego/docker/protocol'

module VCAP::CloudController
  module Diego
    module Docker
      describe Protocol do
        before do
          allow(Config.config).to receive(:[]).with(anything).and_call_original
          allow(Config.config).to receive(:[]).with(:diego).and_return(staging: 'optional', running: 'optional')
          allow(Config.config).to receive(:[]).with(:diego_docker).and_return true
        end

        let(:common_protocol) { double(:common_protocol) }

        let(:app) do
          AppFactory.make(docker_image: 'fake/docker_image')
        end

        subject(:protocol) do
          Protocol.new(common_protocol)
        end

        before do
          allow(common_protocol).to receive(:staging_egress_rules).and_return(['staging_egress_rule'])
          allow(common_protocol).to receive(:running_egress_rules).with(app).and_return(['running_egress_rule'])
        end

        describe '#stage_app_request' do
          subject(:request) do
            protocol.stage_app_request(app, 900)
          end

          it 'includes a subject and message for CfMessageBus::MessageBus#publish' do
            expect(request.size).to eq(2)
            expect(request.first).to eq('diego.docker.staging.start')
            expect(request.last).to match_json(protocol.stage_app_message(app, 900))
          end
        end

        describe '#stage_app_message' do
          subject(:message) do
            protocol.stage_app_message(app, 900)
          end

          it 'includes the fields needed to stage a Docker app' do
            expect(message).to eq({
              'app_id' => app.guid,
              'task_id' => app.staging_task_id,
              'memory_mb' => app.memory,
              'disk_mb' => app.disk_quota,
              'file_descriptors' => app.file_descriptors,
              'stack' => app.stack.name,
              'docker_image' => app.docker_image,
              'egress_rules' => ['staging_egress_rule'],
              'timeout' => 900,
            })
          end
        end

        describe '#desire_app_request' do
          subject(:request) do
            protocol.desire_app_request(app)
          end

          it 'includes a subject and message for CfMessageBus::MessageBus#publish' do
            expect(request.size).to eq(2)
            expect(request.first).to eq('diego.docker.desire.app')
            expect(request.last).to match_json(protocol.desire_app_message(app))
          end
        end

        describe '#desire_app_message' do
          subject(:message) do
            protocol.desire_app_message(app)
          end

          it 'includes the fields needed to desire a Docker app' do
            expect(message).to eq({
              'process_guid' => ProcessGuid.from_app(app),
              'memory_mb' => app.memory,
              'disk_mb' => app.disk_quota,
              'file_descriptors' => app.file_descriptors,
              'stack' => app.stack.name,
              'start_command' => app.command,
              'execution_metadata' => app.execution_metadata,
              'environment' => Environment.new(app).as_json,
              'num_instances' => app.desired_instances,
              'routes' => app.uris,
              'log_guid' => app.guid,
              'docker_image' => app.docker_image,
              'health_check_type' => app.health_check_type,
              'egress_rules' => ['running_egress_rule'],
              'etag' => app.updated_at.to_f.to_s,
            })
          end

          context 'when the app has a health_check_timeout' do
            before do
              app.health_check_timeout = 123
            end

            it 'includes the timeout in the message' do
              expect(message['health_check_timeout_in_seconds']).to eq(app.health_check_timeout)
            end
          end
        end

        describe '#stop_staging_app_request' do
          let(:app) do
            AppFactory.make
          end
          let(:task_id) { 'staging_task_id' }

          subject(:request) do
            protocol.stop_staging_app_request(app, task_id)
          end

          it 'returns an array of arguments including the subject and message' do
            expect(request.size).to eq(2)
            expect(request[0]).to eq('diego.docker.staging.stop')
            expect(request[1]).to match_json(protocol.stop_staging_message(app, task_id))
          end
        end

        describe '#stop_staging_message' do
          let(:staging_app) { AppFactory.make }
          let(:task_id) { 'staging_task_id' }
          subject(:message) { protocol.stop_staging_message(staging_app, task_id) }

          it 'is a nats message with the appropriate staging subject and payload' do
            expect(message).to eq(
              'app_id' => staging_app.guid,
              'task_id' => task_id,
            )
          end
        end

        describe '#stop_index_request' do
          let(:app) { AppFactory.make }
          before { allow(common_protocol).to receive(:stop_index_request) }

          it 'delegates to the common protocol' do
            protocol.stop_index_request(app, 33)

            expect(common_protocol).to have_received(:stop_index_request).with(app, 33)
          end
        end
      end
    end
  end
end
