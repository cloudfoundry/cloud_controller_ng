require 'spec_helper'
require 'cloud_controller/diego/docker/protocol'

module VCAP::CloudController
  module Diego
    module Docker
      describe Protocol do
        before do
          TestConfig.override(diego_docker: true)
        end

        let(:default_health_check_timeout) { 9999 }
        let(:staging_config) { TestConfig.config[:staging] }
        let(:common_protocol) { double(:common_protocol) }
        let(:app) { AppFactory.make(docker_image: 'fake/docker_image', health_check_timeout: 120) }

        subject(:protocol) do
          Protocol.new(common_protocol)
        end

        before do
          allow(common_protocol).to receive(:staging_egress_rules).and_return(['staging_egress_rule'])
          allow(common_protocol).to receive(:running_egress_rules).with(app).and_return(['running_egress_rule'])
        end

        describe '#stage_app_request' do
          subject(:request) do
            protocol.stage_app_request(app, staging_config)
          end

          it 'includes a subject and message for CfMessageBus::MessageBus#publish' do
            expect(request.size).to eq(2)
            expect(request.first).to eq('diego.docker.staging.start')
            expect(request.last).to eq(protocol.stage_app_message(app, staging_config).to_json)
          end
        end

        describe '#stage_app_message' do
          before do
            staging_override = {
              minimum_staging_memory_mb: 128,
              minimum_staging_disk_mb: 128,
              minimum_staging_file_descriptor_limit: 128,
              timeout_in_seconds: 90,
              auth: { user: 'user', password: 'password' },
            }
            TestConfig.override(staging: staging_override)
          end

          let(:message) { protocol.stage_app_message(app, staging_config) }

          it 'contains the correct payload for staging a Docker app' do
            expect(message).to eq({
              app_id: app.guid,
              log_guid: app.guid,
              environment: Environment.new(app).as_json,
              memory_mb: app.memory,
              disk_mb: app.disk_quota,
              file_descriptors: app.file_descriptors,
              stack: app.stack.name,
              egress_rules: ['staging_egress_rule'],
              timeout: 90,
              lifecycle: 'docker',
              lifecycle_data: {
                docker_image: app.docker_image,
              },
            })
          end

          context 'when the app memory is less than the minimum staging memory' do
            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', memory: 127) }

            subject(:message) do
              protocol.stage_app_message(app, staging_config)
            end

            it 'uses the minimum staging memory' do
              expect(message[:memory_mb]).to eq(staging_config[:minimum_staging_memory_mb])
            end
          end

          context 'when the app disk is less than the minimum staging disk' do
            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', disk_quota: 127) }

            subject(:message) do
              protocol.stage_app_message(app, staging_config)
            end

            it 'includes the fields needed to stage a Docker app' do
              expect(message[:disk_mb]).to eq(staging_config[:minimum_staging_disk_mb])
            end
          end

          context 'when the app fd limit is less than the minimum staging fd limit' do
            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', file_descriptors: 127) }

            subject(:message) do
              protocol.stage_app_message(app, staging_config)
            end

            it 'includes the fields needed to stage a Docker app' do
              expect(message[:file_descriptors]).to eq(staging_config[:minimum_staging_file_descriptor_limit])
            end
          end
        end

        describe '#desire_app_request' do
          subject(:request) do
            protocol.desire_app_request(app, default_health_check_timeout)
          end

          it 'includes a subject and message for CfMessageBus::MessageBus#publish' do
            expect(request.size).to eq(2)
            expect(request.first).to eq('diego.docker.desire.app')
            expect(request.last).to match_json(protocol.desire_app_message(app, default_health_check_timeout))
          end
        end

        describe '#desire_app_message' do
          subject(:message) do
            protocol.desire_app_message(app, default_health_check_timeout)
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
              'health_check_timeout_in_seconds' => app.health_check_timeout,
              'egress_rules' => ['running_egress_rule'],
              'etag' => app.updated_at.to_f.to_s,
            })
          end

          context 'when the app health check timeout is not set' do
            before do
              TestConfig.override(default_health_check_timeout: default_health_check_timeout)
            end

            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', health_check_timeout: nil) }

            it 'uses the default app health check from the config' do
              expect(message['health_check_timeout_in_seconds']).to eq(default_health_check_timeout)
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
