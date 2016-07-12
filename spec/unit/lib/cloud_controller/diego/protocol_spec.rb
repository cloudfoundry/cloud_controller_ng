require 'spec_helper'
require_relative 'lifecycle_protocol_shared'

module VCAP::CloudController
  module Diego
    class FakeLifecycleProtocol
      def lifecycle_data(_)
        ['fake', { 'some' => 'data' }]
      end

      def desired_app_message(_)
        { 'more' => 'data', 'start_command' => '/usr/local/bin/party' }
      end
    end

    RSpec.describe FakeLifecycleProtocol do
      let(:lifecycle_protocol) { FakeLifecycleProtocol.new }

      it_behaves_like 'a lifecycle protocol'
    end

    RSpec.describe Protocol do
      let(:blobstore_url_generator) do
        instance_double(CloudController::Blobstore::UrlGenerator,
          buildpack_cache_download_url: 'http://buildpack-artifacts-cache.com',
          app_package_download_url: 'http://app-package.com',
          unauthorized_perma_droplet_download_url: 'fake-droplet_uri',
          buildpack_cache_upload_url: 'http://buildpack-artifacts-cache.up.com',
          droplet_upload_url: 'http://droplet-upload-uri',
        )
      end

      let(:default_health_check_timeout) { 99 }
      let(:config) { TestConfig.config }
      let(:egress_rules) { double(:egress_rules) }
      let(:ports) { [2222, 3333] }
      let(:type) { 'web' }
      let(:app) do
        AppFactory.make(
          health_check_timeout: default_health_check_timeout,
          command: 'start_me',
          diego: true,
          type: type,
          ports: ports
        )
      end

      let(:fake_lifecycle_protocol) { FakeLifecycleProtocol.new }

      subject(:protocol) { Protocol.new(app) }

      before do
        allow(EgressRules).to receive(:new).and_return(egress_rules)
        allow(egress_rules).to receive(:staging).and_return(['staging_egress_rule'])
        allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])
      end

      describe '#stage_app_request' do
        let(:staging_env) { { 'KEY' => 'staging_value' } }

        before do
          override = {
            external_port: external_port,
            internal_service_hostname: internal_service_hostname,
            internal_api: {
              auth_user: user,
              auth_password: password
            },
            staging: {
              minimum_staging_memory_mb: 128,
              minimum_staging_disk_mb: 128,
              minimum_staging_file_descriptor_limit: 128,
              timeout_in_seconds: 90,
              auth: { user: 'user', password: 'password' },
            }
          }
          TestConfig.override(override)

          group = EnvironmentVariableGroup.staging
          group.environment_json = staging_env
          group.save
          allow(protocol).to receive(:lifecycle_protocol).and_return(fake_lifecycle_protocol)
        end

        let(:internal_service_hostname) { 'internal.awesome.sauce' }
        let(:external_port) { '7777' }
        let(:staging_guid) { StagingGuid.from_process(app) }
        let(:user) { 'user' }
        let(:password) { 'password' }

        let(:message) { protocol.stage_app_request(config) }
        let(:app) { AppFactory.make(staging_task_id: 'fake-staging-task-id', diego: true) }

        it 'contains the correct payload for staging a buildpack app' do
          expect(message).to eq({
            app_id: app.guid,
            log_guid: app.guid,
            memory_mb: app.memory,
            disk_mb: app.disk_quota,
            file_descriptors: app.file_descriptors,
            environment: Environment.new(app, staging_env).as_json,
            egress_rules: ['staging_egress_rule'],
            timeout: 90,
            lifecycle: fake_lifecycle_protocol.lifecycle_data(double(:app))[0],
            lifecycle_data: fake_lifecycle_protocol.lifecycle_data(double(:app))[1],
            completion_callback: "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/staging/#{staging_guid}/completed"
          })
        end

        context 'when the app memory is less than the minimum staging memory' do
          let(:app) { AppFactory.make(memory: 127, diego: true) }

          subject(:message) do
            protocol.stage_app_request(config)
          end

          it 'uses the minimum staging memory' do
            expect(message[:memory_mb]).to eq(config[:staging][:minimum_staging_memory_mb])
          end
        end

        context 'when the app disk is less than the minimum staging disk' do
          let(:app) { AppFactory.make(disk_quota: 127, diego: true) }

          subject(:message) do
            protocol.stage_app_request(config)
          end

          it 'includes the fields needed to stage a Docker app' do
            expect(message[:disk_mb]).to eq(config[:staging][:minimum_staging_disk_mb])
          end
        end

        context 'when the app fd limit is less than the minimum staging fd limit' do
          let(:app) { AppFactory.make(file_descriptors: 127, diego: true) }

          subject(:message) do
            protocol.stage_app_request(config)
          end

          it 'includes the fields needed to stage a Docker app' do
            expect(message[:file_descriptors]).to eq(config[:staging][:minimum_staging_file_descriptor_limit])
          end
        end
      end

      describe '#desire_app_request' do
        let(:request) { protocol.desire_app_request(default_health_check_timeout) }

        before do
          allow(protocol).to receive(:lifecycle_protocol).and_return(fake_lifecycle_protocol)
        end

        it 'returns the message' do
          expect(request).to match_json(protocol.desire_app_message(default_health_check_timeout).as_json)
        end
      end

      describe '#desire_app_message' do
        let(:message) { protocol.desire_app_message(default_health_check_timeout) }

        let(:running_env) { { 'KEY' => 'running_value' } }

        let(:route_without_service) { Route.make(space: app.space) }
        let(:route_with_service) do
          si = ManagedServiceInstance.make(:routing, space: app.space)
          r = Route.make(space: app.space)
          RouteBinding.make(route: r, service_instance: si, route_service_url: 'http://foobar.com')
          r
        end

        before do
          group = EnvironmentVariableGroup.running
          group.environment_json = running_env
          group.save

          app.add_route(route_without_service)
          app.add_route(route_with_service)
          app.current_droplet.execution_metadata = 'foobar'

          allow(protocol).to receive(:lifecycle_protocol).and_return(fake_lifecycle_protocol)
        end

        it 'is a message with the information nsync needs to desire the app' do
          # TODO: The test shouldn't be a copy/paste of the implementation
          expect(message.as_json).to match({
            'disk_mb' => app.disk_quota,
            'environment' => Environment.new(app, running_env).as_json,
            'file_descriptors' => app.file_descriptors,
            'health_check_type' => app.health_check_type,
            'health_check_timeout_in_seconds' => app.health_check_timeout,
            'log_guid' => app.guid,
            'log_source' => 'APP',
            'memory_mb' => app.memory,
            'num_instances' => app.desired_instances,
            'process_guid' => ProcessGuid.from_process(app),
            'stack' => app.stack.name,
            'execution_metadata' => app.execution_metadata,
            'routes' => [
              route_without_service.uri,
              route_with_service.uri
            ],
            'routing_info' => {
              'http_routes' => [
                { 'hostname' => route_without_service.uri,
                  'port' => 2222,
                },
                { 'hostname' => route_with_service.uri,
                  'route_service_url' => route_with_service.route_binding.route_service_url,
                  'port' => 2222,
                }
              ]
            },
            'egress_rules' => ['running_egress_rule'],
            'etag' => app.updated_at.to_f.to_s,
            'allow_ssh' => true,
            'ports' => [2222, 3333],
            'network' => {
              'properties' => {
                'policy_group_id' => app.guid,
                'app_id' => app.guid,
                'space_id' => app.space.guid,
                'org_id' => app.organization.guid,
              }
            },
            'volume_mounts' => an_instance_of(Array)
          }.merge(fake_lifecycle_protocol.desired_app_message(double(:app))))
        end

        context 'when app does not have ports defined' do
          let(:ports) { nil }

          context 'when this is a docker app' do
            before do
              allow(app).to receive(:docker_image).and_return('docker/image')
              allow(app).to receive(:docker_ports).and_return([123, 456])
            end

            it 'uses the saved docker ports' do
              expect(message['ports']).to eq([123, 456])
            end
          end

          context 'when this is a buildpack app' do
            context 'when the type is web' do
              let(:type) { 'web' }

              it 'defaults to [8080]' do
                expect(message['ports']).to eq([8080])
              end
            end

            context 'when the type is not web' do
              let(:type) { 'other' }

              it 'default to []' do
                expect(message['ports']).to eq([])
              end
            end
          end
        end

        context 'when the app health check timeout is not set' do
          before do
            TestConfig.override(default_health_check_timeout: default_health_check_timeout)
          end

          let(:app) { AppFactory.make(health_check_timeout: nil, diego: true) }

          it 'uses the default app health check from the config' do
            expect(message['health_check_timeout_in_seconds']).to eq(default_health_check_timeout)
          end
        end

        describe 'log_guid' do
          context 'when the app is v2' do
            it 'is the v2 app guid' do
              expect(message).to match(hash_including('log_guid' => app.guid))
            end
          end

          context 'when the app is v3' do
            let(:parent_app) { AppModel.make }
            before do
              app.app_guid = parent_app.guid
              app.save
            end

            it 'is the v3 app guid' do
              expect(message).to match(hash_including('log_guid' => app.app.guid))
            end
          end
        end

        describe 'log_source' do
          context 'when the app is v2' do
            it 'is "APP"' do
              expect(message).to match(hash_including('log_source' => 'APP'))
            end
          end

          context 'when the app is v3' do
            let(:parent_app) { AppModel.make }
            before do
              app.type = 'potato'
              app.app_guid = parent_app.guid
              app.save
            end

            it 'includes the process type' do
              expect(message).to match(hash_including('log_source' => 'APP/PROC/POTATO'))
            end
          end
        end
      end

      describe '#lifecycle_protocol' do
        context 'docker app' do
          before do
            allow(app).to receive(:docker?).and_return(true)
          end

          it 'is a docker lifecycle protocol' do
            expect(protocol.lifecycle_protocol).to be_a(Diego::Docker::LifecycleProtocol)
          end
        end

        context 'buildpack app' do
          before do
            allow(app).to receive(:docker?).and_return(false)
          end

          it 'is a buildpack lifecycle protocol' do
            expect(protocol.lifecycle_protocol).to be_a(Diego::Buildpack::LifecycleProtocol)
          end
        end
      end
    end
  end
end
