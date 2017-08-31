require 'spec_helper'
require_relative 'lifecycle_protocol_shared'
require 'isolation_segment_assign'

module VCAP::CloudController
  module Diego
    class FakeLifecycleProtocol
      def lifecycle_data(_)
        { 'some' => 'data' }
      end

      def desired_app_message(_)
        { 'more' => 'data', 'start_command' => '/usr/local/bin/party' }
      end

      def staging_action_builder(_, _)
        nil
      end
    end

    RSpec.describe FakeLifecycleProtocol do
      let(:lifecycle_protocol) { FakeLifecycleProtocol.new }

      it_behaves_like 'a lifecycle protocol'
    end

    RSpec.describe Protocol do
      subject(:protocol) { Protocol.new }

      let(:config) { TestConfig.config_instance }
      let(:egress_rules) { instance_double(EgressRules) }
      let(:fake_lifecycle_protocol) { FakeLifecycleProtocol.new }
      let(:running_env) { { 'KEY' => 'running_value' } }

      before do
        group = EnvironmentVariableGroup.running
        group.environment_json = running_env
        group.save

        allow(egress_rules).to receive(:running).and_return(['running_egress_rule'])
        allow(LifecycleProtocol).to receive(:protocol_for_type).and_return(fake_lifecycle_protocol)

        allow(EgressRules).to receive(:new).and_return(egress_rules)
      end

      describe '#stage_package_request' do
        let(:app) { AppModel.make }
        let(:package) { PackageModel.make(app: app) }
        let(:droplet) { DropletModel.make(package: package, app: app) }
        let(:staging_details) do
          Diego::StagingDetails.new.tap do |details|
            details.staging_guid          = droplet.guid
            details.package               = package
            details.environment_variables = { 'nightshade_fruit' => 'potato' }
            details.staging_memory_in_mb  = 42
            details.staging_disk_in_mb    = 51
            details.start_after_staging   = true
            details.lifecycle             = lifecycle
          end
        end
        let(:lifecycle_type) { 'buildpack' }
        let(:staging_message) { BuildCreateMessage.new(lifecycle: { data: {}, type: lifecycle_type }) }
        let(:lifecycle) do
          LifecycleProvider.provide(package, staging_message)
        end
        let(:config) do
          Config.new({
            external_port:             external_port,
            internal_service_hostname: internal_service_hostname,
            internal_api:              {
              auth_user:     user,
              auth_password: password
            },
            staging:                   {
              minimum_staging_memory_mb:             128,
              minimum_staging_file_descriptor_limit: 30,
              timeout_in_seconds:                    90,
            }
          })
        end
        let(:internal_service_hostname) { 'internal.awesome.sauce' }
        let(:external_port) { '7777' }
        let(:user) { 'user' }
        let(:password) { 'password' }
        let(:result) { protocol.stage_package_request(config, staging_details) }

        before do
          allow(LifecycleProtocol).to receive(:protocol_for_type).and_return(fake_lifecycle_protocol)
          expect(egress_rules).to receive(:staging).with(app_guid: app.guid).and_return(['staging_egress_rule'])
        end

        it 'contains the correct payload for staging a package' do
          expect(result).to eq({
            app_id:              staging_details.staging_guid,
            log_guid:            app.guid,
            memory_mb:           staging_details.staging_memory_in_mb,
            disk_mb:             staging_details.staging_disk_in_mb,
            file_descriptors:    30,
            environment:         VCAP::CloudController::Diego::NormalEnvHashToDiegoEnvArrayPhilosopher.muse(staging_details.environment_variables),
            egress_rules:        ['staging_egress_rule'],
            timeout:             90,
            lifecycle:           lifecycle_type,
            lifecycle_data:      { 'some' => 'data' },
            completion_callback: "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}" \
            "/internal/v3/staging/#{droplet.guid}/build_completed?start=#{staging_details.start_after_staging}"
          })
        end
      end

      describe '#desire_app_request' do
        let(:process) { ProcessModelFactory.make }
        let(:default_health_check_timeout) { 99 }
        let(:request) { protocol.desire_app_request(process, default_health_check_timeout) }

        before do
          allow(egress_rules).to receive(:running).with(process).and_return(['running_egress_rule'])
          allow(LifecycleProtocol).to receive(:protocol_for_type).and_return(fake_lifecycle_protocol)
        end

        it 'returns the message' do
          expect(request).to match_json(protocol.desire_app_message(process, default_health_check_timeout).as_json)
        end
      end

      describe '#desire_app_message' do
        let(:space) { Space.make }
        let(:process) { ProcessModelFactory.make(space: space, diego: true, ports: ports, type: type, health_check_timeout: 12) }
        let(:default_health_check_timeout) { 99 }
        let(:message) { protocol.desire_app_message(process, default_health_check_timeout) }
        let(:ports) { [2222, 3333] }
        let(:type) { 'web' }

        let(:route_without_service) { Route.make(space: process.space) }
        let(:route_with_service) do
          si = ManagedServiceInstance.make(:routing, space: process.space)
          r = Route.make(space: process.space)
          RouteBinding.make(route: r, service_instance: si, route_service_url: 'http://foobar.com')
          r
        end

        before do
          group = EnvironmentVariableGroup.running
          group.environment_json = running_env
          group.save

          RouteMappingModel.make(app: process.app, route: route_without_service, process_type: process.type, app_port: 2222)
          RouteMappingModel.make(app: process.app, route: route_with_service, process_type: process.type, app_port: 2222)
          process.current_droplet.execution_metadata = 'foobar'

          allow(egress_rules).to receive(:running).with(process).and_return(['running_egress_rule'])
          allow(LifecycleProtocol).to receive(:protocol_for_type).and_return(fake_lifecycle_protocol)
          allow(VCAP::CloudController::IsolationSegmentSelector).to receive(:for_space).and_return('segment-from-selector')
        end

        it 'is a message with the information nsync needs to desire the app' do
          # TODO: The test shouldn't be a copy/paste of the implementation
          expect(message.as_json).to match({
            'disk_mb' => process.disk_quota,
            'environment' => Environment.new(process, running_env).as_json,
            'file_descriptors' => process.file_descriptors,
            'health_check_type' => process.health_check_type,
            'health_check_timeout_in_seconds' => process.health_check_timeout,
            'health_check_http_endpoint' => '',
            'log_guid' => process.app.guid,
            'log_source' => 'APP/PROC/WEB',
            'memory_mb' => process.memory,
            'num_instances' => process.desired_instances,
            'process_guid' => ProcessGuid.from_process(process),
            'stack' => process.stack.name,
            'execution_metadata' => process.execution_metadata,
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
            'etag' => process.updated_at.to_f.to_s,
            'allow_ssh' => true,
            'ports' => [2222, 3333],
            'network' => {
              'properties' => {
                'policy_group_id' => process.guid,
                'app_id' => process.guid,
                'space_id' => process.space.guid,
                'org_id' => process.organization.guid,
              }
            },
            'volume_mounts' => an_instance_of(Array),
            'isolation_segment' => 'segment-from-selector'
          }.merge(fake_lifecycle_protocol.desired_app_message(double(:app))))
        end

        context 'when app does not have ports defined' do
          let(:ports) { nil }

          context 'when this is a docker app' do
            let(:process) { ProcessModelFactory.make(docker_image: 'docker/image', diego: true, ports: ports, type: type) }

            before do
              allow(process).to receive(:docker_ports).and_return([123, 456])
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

          let(:process) { ProcessModelFactory.make(health_check_timeout: nil, diego: true) }

          it 'uses the default app health check from the config' do
            expect(message['health_check_timeout_in_seconds']).to eq(default_health_check_timeout)
          end
        end

        context 'when the app health check http endpoint is set' do
          let(:default_health_check_http_endpoint) { '/check' }
          before do
            process.health_check_http_endpoint = default_health_check_http_endpoint
          end
          it 'uses the app health check http endpoint' do
            expect(message['health_check_http_endpoint']).to eq(default_health_check_http_endpoint)
          end
        end

        describe 'log_guid' do
          let(:parent_app) { AppModel.make }
          before do
            process.app_guid = parent_app.guid
            process.save
          end

          it 'is the parent app guid' do
            expect(message).to match(hash_including('log_guid' => process.app.guid))
          end
        end

        describe 'log_source' do
          it 'includes the process type' do
            process.type = 'potato'
            process.save
            expect(message).to match(hash_including('log_source' => 'APP/PROC/POTATO'))
          end
        end
      end
    end
  end
end
