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

        let(:app) do
          AppFactory.make(
            docker_image: 'fake/docker_image',
            health_check_timeout: 120,
            enable_ssh: true,
          )
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
            protocol.stage_app_request(app, staging_config)
          end

          it 'returns the staging request message to be used by the stager client' do
            expect(request).to eq(protocol.stage_app_message(app, staging_config).to_json)
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

          it 'returns the message' do
            expect(request).to match_json(protocol.desire_app_message(app, default_health_check_timeout))
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
              'allow_ssh' => true,
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

          context 'when there is a cached_docker_image' do
            let(:cached_docker_image) { '10.244.2.6:8080/uuid' }
            let(:app) { AppFactory.make(docker_image: 'cloudfoundry/diego-docker-app:latest') }

            before { app.current_droplet.cached_docker_image = cached_docker_image }

            it 'uses the cached_docker_image instead of the user provided' do
              expect(message['docker_image']).to eq(cached_docker_image)
            end
          end

          context 'when there is no current_droplet for app' do
            let(:docker_image) { 'cloudfoundry/diego-docker-app:latest' }
            let(:app) do
              App.new(
                name: Sham.name,
                space: Space.make,
                stack: Stack.default,
                docker_image: docker_image,
              )
            end

            it 'uses the user provided docker image' do
              expect(message['docker_image']).to eq(docker_image)
            end
          end
        end
      end
    end
  end
end
