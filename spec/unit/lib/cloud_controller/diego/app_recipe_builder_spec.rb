require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe AppRecipeBuilder do
      subject(:builder) do
        AppRecipeBuilder.new(
          config:,
          process:,
          ssh_key:
        )
      end

      let(:ssh_key) { SSHKey.new }

      shared_examples_for 'creating a desired lrp' do
        it 'creates a desired lrp' do
          lrp = builder.build_app_lrp
          expect(lrp.action).to eq(expected_action)
          expect(lrp.annotation).to eq(Time.at(2).to_f.to_s)
          expect(lrp.cached_dependencies).to eq(expected_cached_dependencies)
          expect(lrp.disk_mb).to eq(256)
          expect(lrp.domain).to eq(APP_LRP_DOMAIN)
          expect(lrp.egress_rules).to contain_exactly(rule_dns_everywhere, rule_http_everywhere, rule_staging_specific)
          expect(lrp.legacy_download_user).to eq('lrp-action-user')
          expect(lrp.instances).to eq(21)
          expect(lrp.log_guid).to eq(process.app.guid)
          expect(lrp.log_source).to eq(LRP_LOG_SOURCE)
          expect(lrp.max_pids).to eq(100)
          expect(lrp.memory_mb).to eq(128)
          expect(lrp.log_rate_limit.bytes_per_second).to eq(1024)
          expect(lrp.metrics_guid).to eq(process.app.guid)

          expect(lrp.metric_tags.keys.size).to eq(11)
          expect(lrp.metric_tags['source_id'].static).to eq(process.app.guid)
          expect(lrp.metric_tags['process_id'].static).to eq(process.guid)
          expect(lrp.metric_tags['process_type'].static).to eq(process.type)
          expect(lrp.metric_tags['process_instance_id'].dynamic).to eq(:INSTANCE_GUID)
          expect(lrp.metric_tags['instance_id'].dynamic).to eq(:INDEX)
          expect(lrp.metric_tags['organization_id'].static).to eq(org.guid)
          expect(lrp.metric_tags['space_id'].static).to eq(space.guid)
          expect(lrp.metric_tags['app_id'].static).to eq(app_model.guid)
          expect(lrp.metric_tags['organization_name'].static).to eq(org.name)
          expect(lrp.metric_tags['space_name'].static).to eq(space.name)
          expect(lrp.metric_tags['app_name'].static).to eq(app_model.name)

          expect(lrp.monitor).to eq(expected_monitor_action)
          expect(lrp.network).to eq(expected_network)
          expect(lrp.ports).to eq([4444, 5555])
          expect(lrp.process_guid).to eq(ProcessGuid.from_process(process))
          expect(lrp.start_timeout_ms).to eq(12 * 1000)
          expect(lrp.trusted_system_certificates_path).to eq(RUNNING_TRUSTED_SYSTEM_CERT_PATH)
          expect(lrp.PlacementTags).to eq(['placement-tag'])
          expect(lrp.certificate_properties).to eq(expected_certificate_properties)

          expect(lrp.volume_mounted_files).to be_empty
        end
      end

      shared_examples 'file-based service bindings' do
        context 'when file-based service bindings are enabled' do
          before do
            app = process.app
            app.update(file_based_service_bindings_enabled: true)
            VCAP::CloudController::ServiceBinding.make(service_instance: ManagedServiceInstance.make(space: app.space), app: app)
          end

          it 'includes volume mounted files' do
            lrp = builder.build_app_lrp
            expect(lrp.volume_mounted_files).not_to be_empty
          end
        end
      end

      before do
        TestConfig.override(credhub_api: nil)
      end

      describe '#build_app_lrp' do
        before do
          environment = instance_double(Environment)
          allow(Environment).to receive(:new).with(process, {}).and_return(environment)
          allow(environment).to receive(:as_json).and_return(environment_variables)
          [
            SecurityGroup.make(guid: 'guid1', rules: [{ 'protocol' => 'udp', 'ports' => '53', 'destination' => '0.0.0.0/0' }]),
            SecurityGroup.make(guid: 'guid2', rules: [{ 'protocol' => 'tcp', 'ports' => '80', 'destination' => '0.0.0.0/0', 'log' => true }]),
            SecurityGroup.make(guid: 'guid3', rules: [{ 'protocol' => 'tcp', 'ports' => '443', 'destination' => '0.0.0.0/0', 'log' => true }])
          ].each { |security_group| security_group.add_space(process.space) }

          RouteMappingModel.make(app: process.app, route: route_without_service, process_type: process.type, app_port: 1111)
          RouteMappingModel.make(app: process.app, route: route_with_service, process_type: process.type, app_port: 1111)

          app_model.update(droplet:)
          allow(VCAP::CloudController::IsolationSegmentSelector).to receive(:for_space).and_return('placement-tag')
          process.desired_droplet.execution_metadata = execution_metadata
        end

        let(:environment_variables) { [{ 'name' => 'KEY', 'value' => 'running_value' }] }
        let(:port_environment_variables) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '4444')
          ]
        end

        let(:lifecycle_type) { nil }
        let(:org) { Organization.make(name: 'MyOrg') }
        let(:space) { Space.make(organization: org) }
        let(:app_model) { AppModel.make(lifecycle_type, guid: 'app-guid', space: space, droplet: DropletModel.make(state: 'STAGED'), enable_ssh: false) }
        let(:package) { PackageModel.make(lifecycle_type, app: app_model) }
        let(:process) do
          process = ProcessModel.make(:process,
                                      app: app_model,
                                      state: 'STARTED',
                                      diego: true,
                                      guid: 'process-guid',
                                      type: 'web',
                                      health_check_timeout: 12,
                                      instances: 21,
                                      memory: 128,
                                      disk_quota: 256,
                                      log_rate_limit: 1024,
                                      command: command,
                                      file_descriptors: 32,
                                      health_check_type: 'port',
                                      enable_ssh: false)
          process.this.update(updated_at: Time.at(2))
          process.reload
        end
        let(:command) { 'echo "hello"' }

        let(:route_without_service) { Route.make(space: process.space) }
        let(:route_with_service) do
          si = ManagedServiceInstance.make(:routing, space: process.space)
          r  = Route.make(space: process.space)
          RouteBinding.make(route: r, service_instance: si, route_service_url: 'http://foobar.com')
          r
        end

        let(:ports) { '8080' }
        let(:expected_network) do
          ::Diego::Bbs::Models::Network.new(
            properties: {
              'policy_group_id' => app_model.guid,
              'app_id' => app_model.guid,
              'space_id' => app_model.space.guid,
              'org_id' => app_model.organization.guid,
              'ports' => ports,
              'container_workload' => Protocol::ContainerNetworkInfo::APP
            }
          )
        end
        let(:expected_action_environment_variables) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '4444'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'KEY', value: 'running_value')
          ]
        end

        let(:expected_action) do
          ::Diego::Bbs::Models::Action.new(
            codependent_action: ::Diego::Bbs::Models::CodependentAction.new(actions: expected_run_actions)
          )
        end
        let(:expected_app_run_action) do
          ::Diego::Bbs::Models::Action.new(
            run_action: ::Diego::Bbs::Models::RunAction.new(
              path: '/tmp/lifecycle/launcher',
              args: ['app', command, execution_metadata],
              log_source: 'APP/PROC/WEB',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
              env: expected_action_environment_variables,
              user: 'lrp-action-user'
            )
          )
        end
        let(:expected_run_actions) { [expected_app_run_action] }
        let(:expected_monitor_action) do
          ::Diego::Bbs::Models::Action.new(
            timeout_action: ::Diego::Bbs::Models::TimeoutAction.new(
              timeout_ms: 600_000,
              action: ::Diego::Bbs::Models::Action.new(
                parallel_action: ::Diego::Bbs::Models::ParallelAction.new(
                  actions: [
                    ::Diego::Bbs::Models::Action.new(
                      run_action: ::Diego::Bbs::Models::RunAction.new(
                        user: 'lrp-action-user',
                        path: '/tmp/lifecycle/healthcheck',
                        args: ['-port=4444'],
                        resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                        log_source: HEALTH_LOG_SOURCE,
                        suppress_log_output: true
                      )
                    ),
                    ::Diego::Bbs::Models::Action.new(
                      run_action: ::Diego::Bbs::Models::RunAction.new(
                        user: 'lrp-action-user',
                        path: '/tmp/lifecycle/healthcheck',
                        args: ['-port=5555'],
                        resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                        log_source: HEALTH_LOG_SOURCE,
                        suppress_log_output: true
                      )
                    )
                  ]
                )
              )
            )
          )
        end
        let(:expected_file_descriptor_limit) { 32 }
        let(:expected_cached_dependencies) do
          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: 'lifecycle-from',
              to: 'lifecycle-to',
              cache_key: 'lifecycle-key'
            )
          ]
        end

        let(:expected_certificate_properties) do
          ::Diego::Bbs::Models::CertificateProperties.new(
            organizational_unit: [
              "organization:#{process.app.organization.guid}",
              "space:#{process.app.space.guid}",
              "app:#{process.app.guid}"
            ]
          )
        end

        let(:lrp_builder_ports) { [4444, 5555] }

        let(:rule_dns_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol: 'udp',
            destinations: ['0.0.0.0/0'],
            ports: [53],
            annotations: ['security_group_id:guid1']
          )
        end
        let(:rule_http_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol: 'tcp',
            destinations: ['0.0.0.0/0'],
            ports: [80],
            log: true,
            annotations: ['security_group_id:guid2']
          )
        end
        let(:rule_staging_specific) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol: 'tcp',
            destinations: ['0.0.0.0/0'],
            ports: [443],
            log: true,
            annotations: ['security_group_id:guid3']
          )
        end
        let(:execution_metadata) { { user: execution_metadata_user }.to_json }
        let(:execution_metadata_user) { nil }

        context 'when the lifecycle_type is "buildpack"' do
          let(:lifecycle_type) { :buildpack }
          let(:droplet) do
            DropletModel.make(lifecycle_type,
                              package: package,
                              state: DropletModel::STAGED_STATE,
                              execution_metadata: execution_metadata,
                              droplet_hash: 'droplet-hash')
          end
          let(:config) do
            Config.new({
                         diego: {
                           use_privileged_containers_for_running: false,
                           lifecycle_bundles: {
                             'potato-stack' => 'some-uri'
                           },
                           pid_limit: 100
                         }
                       })
          end
          let(:expected_cached_dependencies) do
            [
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'lifecycle-from',
                to: 'lifecycle-to',
                cache_key: 'lifecycle-cache-key'
              )
            ]
          end
          let(:expected_setup_action) { ::Diego::Bbs::Models::Action.new }
          let(:expected_image_layers) { [::Diego::Bbs::Models::ImageLayer.new] }
          let(:env_vars) { [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'foo', value: 'bar')] }

          let(:desired_lrp_builder) do
            instance_double(VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder,
                            cached_dependencies: expected_cached_dependencies,
                            root_fs: 'buildpack_root_fs',
                            setup: expected_setup_action,
                            global_environment_variables: env_vars,
                            privileged?: false,
                            ports: lrp_builder_ports,
                            port_environment_variables: port_environment_variables,
                            action_user: 'lrp-action-user',
                            image_layers: expected_image_layers,
                            start_command: command)
          end

          let(:ports) { '8080' }

          before do
            VCAP::CloudController::BuildpackLifecycleDataModel.make(
              app: app_model,
              buildpacks: nil,
              stack: 'potato-stack'
            )

            allow(VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder).to receive(:new).and_return(desired_lrp_builder)
          end

          it_behaves_like 'creating a desired lrp'

          it 'creates a desired lrp with buildpack specific properties' do
            lrp = builder.build_app_lrp
            expect(lrp.environment_variables).to contain_exactly(::Diego::Bbs::Models::EnvironmentVariable.new(name: 'foo', value: 'bar'))
            expect(lrp.root_fs).to eq('buildpack_root_fs')
            expect(lrp.setup).to eq(expected_setup_action)
            expect(lrp.image_layers).to eq(expected_image_layers)
          end

          context 'when the space is not entitled to any isolation segments' do
            before do
              allow(VCAP::CloudController::IsolationSegmentSelector).to receive(:for_space).and_return(nil)
            end

            it 'sets PlacementTags to empty array' do
              app_lrp = builder.build_app_lrp
              expect(app_lrp.PlacementTags).to eq []
            end
          end

          context 'when a volume mount is provided' do
            let(:service_instance) { ManagedServiceInstance.make space: app_model.space }
            let(:multiple_volume_mounts) do
              [
                {
                  container_dir: '/data/images',
                  mode: 'r',
                  device_type: 'shared',
                  driver: 'cephfs',
                  device: {
                    volume_id: 'abc',
                    mount_config: {
                      key: 'value'
                    }
                  }
                },
                {
                  container_dir: '/data/scratch',
                  mode: 'rw',
                  device_type: 'shared',
                  driver: 'local',
                  device: {
                    volume_id: 'def',
                    mount_config: {}
                  }
                }
              ]
            end

            before do
              ServiceBinding.make(app: app_model, service_instance: service_instance, volume_mounts: multiple_volume_mounts)
            end

            it 'desires the mount' do
              lrp = builder.build_app_lrp
              expect(lrp.volume_mounts).to eq([
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver: 'cephfs',
                  container_dir: '/data/images',
                  mode: 'r',
                  shared: ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'abc', mount_config: { 'key' => 'value' }.to_json)
                ),
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver: 'local',
                  container_dir: '/data/scratch',
                  mode: 'rw',
                  shared: ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'def', mount_config: '')
                )
              ])
            end
          end

          context 'healthcheck' do
            context 'when the health_check_timeout is not set on process' do
              before do
                process.update(health_check_timeout: nil)
                config.set(:default_health_check_timeout, 12_345)
              end

              it 'falls back to the default located in the config' do
                lrp = builder.build_app_lrp
                expect(lrp.start_timeout_ms).to eq(12_345_000)
              end

              it 'sets the healthcheck definition timeout to the default' do
                lrp = builder.build_app_lrp
                lrp.check_definition.checks.first.tcp_check
              end
            end

            context 'when the health check type is not set' do
              before do
                process.health_check_type = ''
              end

              it 'adds a port healthcheck action for backwards compatibility' do
                lrp = builder.build_app_lrp

                expect(lrp.monitor).to eq(expected_monitor_action)
              end

              it 'adds a TCP health check definition' do
                lrp       = builder.build_app_lrp
                tcp_check = lrp.check_definition.checks.first.tcp_check
                expect(tcp_check.port).to eq(4444)
              end
            end

            context 'when the health check type is set to "none"' do
              before do
                process.health_check_type = 'none'
              end

              it 'does not add a monitor action' do
                lrp = builder.build_app_lrp

                expect(lrp.monitor).to be_nil
              end

              it 'does not add healthcheck definitions' do
                lrp              = builder.build_app_lrp
                check_definition = lrp.check_definition
                expect(check_definition).to be_nil
              end
            end

            context 'when the health check type is set to "port"' do
              before do
                process.health_check_type = 'port'
              end

              it 'adds a port healthcheck action' do
                lrp = builder.build_app_lrp

                expect(lrp.monitor).to eq(expected_monitor_action)
              end

              it 'adds a TCP health check definition' do
                lrp       = builder.build_app_lrp
                tcp_check = lrp.check_definition.checks.first.tcp_check
                expect(tcp_check.port).to eq(4444)
                expect(tcp_check.connect_timeout_ms).to eq(0)
                monitor_args = lrp.monitor.timeout_action.action.parallel_action.actions.first.run_action.args
                expect(monitor_args).to eq(['-port=4444'])
              end

              it 'does not set connection timeouts' do
                lrp       = builder.build_app_lrp
                tcp_check = lrp.check_definition.checks.first.tcp_check
                expect(tcp_check.connect_timeout_ms).to eq(0)
                monitor_args = lrp.monitor.timeout_action.action.parallel_action.actions.first.run_action.args
                expect(monitor_args).to eq(['-port=4444'])
              end

              context 'when there is an invocation_timeout' do
                before do
                  process.health_check_invocation_timeout = 10
                end

                it 'sets the connect_timeout_ms' do
                  lrp = builder.build_app_lrp
                  tcp_check = lrp.check_definition.checks.first.tcp_check
                  expect(tcp_check.port).to eq(4444)
                  expect(tcp_check.connect_timeout_ms).to eq(10_000)

                  monitor_args = lrp.monitor.timeout_action.action.parallel_action.actions.first.run_action.args
                  expect(monitor_args).to eq(['-port=4444', '-timeout=10s'])
                end
              end

              context 'when there is an interval' do
                before do
                  process.health_check_interval = 7
                end

                it 'sets the connect_timeout_ms' do
                  lrp = builder.build_app_lrp
                  tcp_check = lrp.check_definition.checks.first.tcp_check
                  expect(tcp_check.port).to eq(4444)
                  expect(tcp_check.interval_ms).to eq(7_000)
                end
              end
            end

            context 'when the health check type is set to "http"' do
              before do
                process.health_check_type          = 'http'
                process.health_check_http_endpoint = 'http-endpoint'
                process.health_check_invocation_timeout = 10
              end

              let(:expected_monitor_action) do
                ::Diego::Bbs::Models::Action.new(
                  timeout_action: ::Diego::Bbs::Models::TimeoutAction.new(
                    timeout_ms: 600_000,
                    action: ::Diego::Bbs::Models::Action.new(
                      parallel_action: ::Diego::Bbs::Models::ParallelAction.new(
                        actions: [
                          ::Diego::Bbs::Models::Action.new(
                            run_action: ::Diego::Bbs::Models::RunAction.new(
                              user: 'lrp-action-user',
                              path: '/tmp/lifecycle/healthcheck',
                              args: ['-port=4444', '-uri=http-endpoint', '-timeout=10s'],
                              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                              log_source: HEALTH_LOG_SOURCE,
                              suppress_log_output: true
                            )
                          ),
                          ::Diego::Bbs::Models::Action.new(
                            run_action: ::Diego::Bbs::Models::RunAction.new(
                              user: 'lrp-action-user',
                              path: '/tmp/lifecycle/healthcheck',
                              args: ['-port=5555', '-timeout=10s'],
                              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                              log_source: HEALTH_LOG_SOURCE,
                              suppress_log_output: true
                            )
                          )
                        ]
                      )
                    )
                  )
                )
              end

              it 'adds a http healthcheck action using the first port' do
                lrp = builder.build_app_lrp

                expect(lrp.monitor).to eq(expected_monitor_action)
              end

              it 'adds an HTTP health check definition using the first port' do
                lrp        = builder.build_app_lrp
                http_check = lrp.check_definition.checks.first.http_check
                expect(http_check.port).to eq(4444)
                expect(http_check.path).to eq('http-endpoint')
                expect(http_check.request_timeout_ms).to eq(10_000)
              end

              it 'defaults the HTTP invocation timeout to zero' do
                process.health_check_invocation_timeout = nil
                lrp = builder.build_app_lrp
                http_check = lrp.check_definition.checks.first.http_check
                expect(http_check.port).to eq(4444)
                expect(http_check.path).to eq('http-endpoint')
                expect(http_check.request_timeout_ms).to eq(0)

                monitor_args = lrp.monitor.timeout_action.action.parallel_action.actions.first.run_action.args
                expect(monitor_args).to eq(['-port=4444', '-uri=http-endpoint'])
              end

              it 'keeps a TCP health check definition for other ports' do
                lrp       = builder.build_app_lrp
                tcp_check = lrp.check_definition.checks[1].tcp_check
                expect(tcp_check.port).to eq(5555)
              end
            end

            context 'when the health check type is not recognized' do
              before do
                process.health_check_type = 'foobar'
              end

              it 'adds a port healthcheck action for backwards compatibility' do
                lrp = builder.build_app_lrp

                expect(lrp.monitor).to be_nil
              end

              it 'does not add healthcheck definitions' do
                lrp              = builder.build_app_lrp
                check_definition = lrp.check_definition
                expect(check_definition).to be_nil
              end
            end
          end

          context 'readiness health check' do
            context 'when the readiness health check type defaults to process' do
              before do
                process.readiness_health_check_type = 'process'
              end

              it 'does not add any readiness health checks for backwards compatibility' do
                lrp = builder.build_app_lrp
                expect(lrp.check_definition.readiness_checks).to be_empty
              end
            end

            context 'when the readiness health check type is set to "port"' do
              before do
                process.readiness_health_check_type = 'port'
              end

              it 'adds a TCP readiness health check definition' do
                lrp       = builder.build_app_lrp
                tcp_check = lrp.check_definition.readiness_checks.first.tcp_check
                expect(tcp_check.port).to eq(4444)
                expect(tcp_check.connect_timeout_ms).to eq(0)
              end

              it 'does not set connection timeouts' do
                lrp       = builder.build_app_lrp
                tcp_check = lrp.check_definition.readiness_checks.first.tcp_check
                expect(tcp_check.connect_timeout_ms).to eq(0)
              end

              context 'when there is an invocation_timeout' do
                before do
                  process.readiness_health_check_invocation_timeout = 10
                end

                it 'sets the connect_timeout_ms' do
                  lrp = builder.build_app_lrp
                  tcp_check = lrp.check_definition.readiness_checks.first.tcp_check
                  expect(tcp_check.port).to eq(4444)
                  expect(tcp_check.connect_timeout_ms).to eq(10_000)
                end
              end

              context 'when there is an interval defined' do
                before do
                  process.readiness_health_check_interval = 77
                end

                it 'sets the interval_ms' do
                  lrp = builder.build_app_lrp
                  tcp_check = lrp.check_definition.readiness_checks.first.tcp_check
                  expect(tcp_check.port).to eq(4444)
                  expect(tcp_check.interval_ms).to eq(77_000)
                end
              end
            end

            context 'when the health check type is set to "http"' do
              before do
                process.readiness_health_check_type          = 'http'
                process.readiness_health_check_http_endpoint = '/http-endpoint'
                process.readiness_health_check_invocation_timeout = 10
              end

              it 'adds an HTTP readiness health check definition using the first port' do
                lrp        = builder.build_app_lrp
                http_check = lrp.check_definition.readiness_checks.first.http_check
                expect(http_check.port).to eq(4444)
                expect(http_check.path).to eq('/http-endpoint')
                expect(http_check.request_timeout_ms).to eq(10_000)
              end

              it 'defaults the HTTP invocation timeout to zero' do
                process.readiness_health_check_invocation_timeout = nil
                lrp = builder.build_app_lrp
                http_check = lrp.check_definition.readiness_checks.first.http_check
                expect(http_check.port).to eq(4444)
                expect(http_check.path).to eq('/http-endpoint')
                expect(http_check.request_timeout_ms).to eq(0)
              end

              it 'keeps a TCP readiness health check definition for other ports' do
                lrp       = builder.build_app_lrp
                tcp_check = lrp.check_definition.readiness_checks[1].tcp_check
                expect(tcp_check.port).to eq(5555)
              end
            end

            context 'when the readiness health check type is not recognized' do
              before do
                process.readiness_health_check_type = 'meow'
              end

              it 'does not add readiness healthcheck definitions' do
                lrp              = builder.build_app_lrp
                check_definition = lrp.check_definition
                expect(check_definition.readiness_checks).to be_empty
              end
            end
          end

          describe 'routes' do
            before do
              routing_info = {
                'http_routes' => [
                  {
                    'hostname' => 'potato.example.com',
                    'port' => 8080,
                    'protocol' => 'http2'
                  },
                  {
                    'hostname' => 'tomato.example.com',
                    'port' => 8080,
                    'route_service_url' => 'https://potatosarebetter.example.com',
                    'protocol' => 'http1'
                  }
                ],
                'tcp_routes' => [
                  {
                    'router_group_guid' => 'im-a-guid',
                    'external_port' => 1234,
                    'container_port' => 4321
                  },
                  {
                    'router_group_guid' => 'im-probably-a-guid',
                    'external_port' => 789,
                    'container_port' => 987
                  }
                ],
                'internal_routes' => [
                  {
                    'hostname' => 'app-guid.apps.internal'
                  }
                ]
              }

              routing_info_object = instance_double(Protocol::RoutingInfo)
              allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
              allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
            end

            it 'includes the correct routes' do
              expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                routes: {
                  'cf-router' => [
                    {
                      'hostnames' => ['potato.example.com'],
                      'port' => 8080,
                      'route_service_url' => nil,
                      'isolation_segment' => 'placement-tag',
                      'protocol' => 'http2'
                    },
                    {
                      'hostnames' => ['tomato.example.com'],
                      'port' => 8080,
                      'route_service_url' => 'https://potatosarebetter.example.com',
                      'isolation_segment' => 'placement-tag',
                      'protocol' => 'http1'
                    }
                  ].to_json,
                  'tcp-router' => [
                    {
                      'router_group_guid' => 'im-a-guid',
                      'external_port' => 1234,
                      'container_port' => 4321
                    },
                    {
                      'router_group_guid' => 'im-probably-a-guid',
                      'external_port' => 789,
                      'container_port' => 987
                    }
                  ].to_json,
                  'internal-router' => [
                    {
                      'hostname' => 'app-guid.apps.internal'
                    }
                  ].to_json
                }
              )

              lrp = builder.build_app_lrp

              expect(lrp.routes).to eq(expected_routes)
            end

            context 'when there are no http routes' do
              before do
                routing_info = {
                  'tcp_routes' => [
                    {
                      'router_group_guid' => 'im-a-guid',
                      'external_port' => 1234,
                      'container_port' => 4321
                    },
                    {
                      'router_group_guid' => 'im-probably-a-guid',
                      'external_port' => 789,
                      'container_port' => 987
                    }
                  ],
                  'internal_routes' => [
                    {
                      'hostname' => 'app-guid.apps.internal'
                    }
                  ]
                }

                routing_info_object = instance_double(Protocol::RoutingInfo)
                allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
                allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
              end

              it 'includes empty cf-router entry' do
                expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                  routes: {
                    'cf-router' => [].to_json,
                    'tcp-router' => [
                      {
                        'router_group_guid' => 'im-a-guid',
                        'external_port' => 1234,
                        'container_port' => 4321
                      },
                      {
                        'router_group_guid' => 'im-probably-a-guid',
                        'external_port' => 789,
                        'container_port' => 987
                      }
                    ].to_json,
                    'internal-router' => [
                      {
                        'hostname' => 'app-guid.apps.internal'
                      }
                    ].to_json
                  }
                )

                lrp = builder.build_app_lrp

                expect(lrp.routes).to eq(expected_routes)
              end
            end

            context 'when there are no tcp routes' do
              before do
                routing_info = {
                  'http_routes' => [
                    {
                      'hostname' => 'potato.example.com',
                      'port' => 8080,
                      'protocol' => 'http1'
                    },
                    {
                      'hostname' => 'tomato.example.com',
                      'port' => 8080,
                      'route_service_url' => 'https://potatosarebetter.example.com',
                      'protocol' => 'http2'
                    }

                  ],
                  'internal_routes' => [
                    {
                      'hostname' => 'app-guid.apps.internal'
                    }
                  ]
                }

                routing_info_object = instance_double(Protocol::RoutingInfo)
                allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
                allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
              end

              it 'includes empty tcp-router entry' do
                expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                  routes: {
                    'cf-router' => [
                      {
                        'hostnames' => ['potato.example.com'],
                        'port' => 8080,
                        'route_service_url' => nil,
                        'isolation_segment' => 'placement-tag',
                        'protocol' => 'http1'
                      },
                      {
                        'hostnames' => ['tomato.example.com'],
                        'port' => 8080,
                        'route_service_url' => 'https://potatosarebetter.example.com',
                        'isolation_segment' => 'placement-tag',
                        'protocol' => 'http2'
                      }
                    ].to_json,
                    'tcp-router' => [].to_json,
                    'internal-router' => [
                      {
                        'hostname' => 'app-guid.apps.internal'
                      }
                    ].to_json
                  }
                )

                lrp = builder.build_app_lrp

                expect(lrp.routes).to eq(expected_routes)
              end
            end
          end

          describe 'ssh' do
            before do
              process.app.update(enable_ssh: true)
            end

            it 'includes the ssh port' do
              lrp = builder.build_app_lrp
              expect(desired_lrp_builder.ports).not_to include(2222)
              expect(lrp.ports).to include(2222)
            end

            it 'includes the lrp route' do
              lrp = builder.build_app_lrp
              expect(lrp.routes.routes['diego-ssh']).to eq(Oj.dump({
                                                                     container_port: 2222,
                                                                     private_key: ssh_key.private_key,
                                                                     host_fingerprint: ssh_key.fingerprint
                                                                   }))
            end
          end

          context 'when the same builder is used twice' do
            it 'builds the same app lrp' do
              lrp = builder.build_app_lrp
              expect(lrp.action).to eq(expected_action)
              lrp2 = builder.build_app_lrp
              expect(lrp2.action).to eq(expected_action)
            end
          end

          include_examples 'file-based service bindings'
        end

        context 'when the lifecycle_type is "cnb"' do
          let(:lifecycle_type) { :cnb }
          let(:droplet) do
            DropletModel.make(lifecycle_type,
                              package: package,
                              state: DropletModel::STAGED_STATE,
                              execution_metadata: execution_metadata,
                              droplet_hash: 'droplet-hash')
          end
          let(:config) do
            Config.new({
                         diego: {
                           use_privileged_containers_for_running: false,
                           lifecycle_bundles: {
                             'potato-stack' => 'some-uri'
                           },
                           pid_limit: 100
                         }
                       })
          end
          let(:expected_cached_dependencies) do
            [
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'lifecycle-from',
                to: 'lifecycle-to',
                cache_key: 'lifecycle-cache-key'
              )
            ]
          end
          let(:expected_setup_action) { ::Diego::Bbs::Models::Action.new }
          let(:expected_image_layers) { [::Diego::Bbs::Models::ImageLayer.new] }
          let(:env_vars) { [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'foo', value: 'bar')] }

          let(:desired_lrp_builder) do
            instance_double(VCAP::CloudController::Diego::CNB::DesiredLrpBuilder,
                            cached_dependencies: expected_cached_dependencies,
                            root_fs: 'buildpack_root_fs',
                            setup: expected_setup_action,
                            global_environment_variables: env_vars,
                            privileged?: false,
                            ports: lrp_builder_ports,
                            port_environment_variables: port_environment_variables,
                            action_user: 'lrp-action-user',
                            image_layers: expected_image_layers,
                            start_command: command)
          end

          let(:ports) { '8080' }

          before do
            VCAP::CloudController::BuildpackLifecycleDataModel.make(
              app: app_model,
              buildpacks: nil,
              stack: 'potato-stack'
            )

            allow(VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder).to receive(:new).and_return(desired_lrp_builder)
          end

          it_behaves_like 'creating a desired lrp'

          it 'creates a desired lrp with cnb specific properties' do
            lrp = builder.build_app_lrp
            expect(lrp.environment_variables).to contain_exactly(::Diego::Bbs::Models::EnvironmentVariable.new(name: 'foo', value: 'bar'))
            expect(lrp.root_fs).to eq('buildpack_root_fs')
            expect(lrp.setup).to eq(expected_setup_action)
            expect(lrp.image_layers).to eq(expected_image_layers)
          end

          describe 'ssh' do
            before do
              process.app.update(enable_ssh: true)
            end

            it 'includes the ssh port' do
              lrp = builder.build_app_lrp
              expect(desired_lrp_builder.ports).not_to include(2222)
              expect(lrp.ports).to include(2222)
            end

            it 'includes the lrp route' do
              lrp = builder.build_app_lrp
              expect(lrp.routes.routes['diego-ssh']).to eq(Oj.dump({
                                                                     container_port: 2222,
                                                                     private_key: ssh_key.private_key,
                                                                     host_fingerprint: ssh_key.fingerprint
                                                                   }))
            end
          end

          include_examples 'file-based service bindings'
        end

        context 'when the lifecycle_type is "docker"' do
          let(:config) do
            Config.new({
                         diego: {
                           pid_limit: 100
                         }
                       })
          end
          let(:lifecycle_type) { :docker }
          let(:package) { PackageModel.make(lifecycle_type, app: app_model) }
          let(:droplet) do
            DropletModel.make(:docker,
                              package: package,
                              state: DropletModel::STAGED_STATE,
                              execution_metadata: execution_metadata,
                              docker_receipt_image: 'docker-receipt-image',
                              docker_receipt_username: 'dockeruser',
                              docker_receipt_password: 'dockerpass')
          end
          let(:old_expected_cached_dependencies) do
            [
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'http://file-server.com/v1/static/the/docker/lifecycle/path.tgz',
                to: '/tmp/lifecycle',
                cache_key: 'docker-lifecycle'
              )
            ]
          end

          let(:desired_lrp_builder) do
            instance_double(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder,
                            cached_dependencies: expected_cached_dependencies,
                            root_fs: 'docker_root_fs',
                            setup: nil,
                            global_environment_variables: [],
                            privileged?: false,
                            image_layers: [],
                            ports: lrp_builder_ports,
                            port_environment_variables: port_environment_variables,
                            action_user: 'lrp-action-user',
                            start_command: command)
          end

          before do
            allow(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder).to receive(:new).and_return(desired_lrp_builder)
          end

          it_behaves_like 'creating a desired lrp'

          it 'creates a desired lrp with docker specific properties' do
            lrp = builder.build_app_lrp
            expect(lrp.environment_variables).to eq([])
            expect(lrp.root_fs).to eq('docker_root_fs')
            expect(lrp.privileged).to be false
            expect(lrp.image_username).to eq('dockeruser')
            expect(lrp.image_password).to eq('dockerpass')
          end

          describe 'metric_tags' do
            let(:lrp) { builder.build_app_lrp }
            let(:metric_tag_key_prefix) { 'metric.tag.cloudfoundry.org' }

            before do
              AppLabelModel.make(
                app: app_model,
                key_prefix: metric_tag_key_prefix,
                key_name: 'DatadogValue',
                value: 'woof'
              )

              AppLabelModel.make(
                app: app_model,
                key_prefix: 'nonmetric.tag.cloudfoundry.org',
                key_name: 'SomeotherValue',
                value: 'notapplied'
              )
            end

            context 'when cc.custom_metric_tag_prefix_list has entries' do
              before do
                TestConfig.override(custom_metric_tag_prefix_list: [metric_tag_key_prefix])
              end

              it 'app labels set custom tags' do
                expect(lrp.metric_tags['DatadogValue'].static).to eq 'woof'
                expect(lrp.metric_tags['SomeotherValue']).to be_nil
              end

              context 'when app labels tags match existing custom metrics tags' do
                before do
                  AppLabelModel.make(
                    app: app_model,
                    key_prefix: metric_tag_key_prefix,
                    key_name: 'organization_name',
                    value: 'wrong_org_name'
                  )
                end

                it 'does not override the metric tag' do
                  expect(lrp.metric_tags['organization_name'].static).to eq 'MyOrg'
                end
              end

              context 'when app labels contain forbidden key_names' do
                before do
                  AppLabelModel.make(
                    app: app_model,
                    key_prefix: metric_tag_key_prefix,
                    key_name: 'deployment',
                    value: 'kafka'
                  )

                  AppLabelModel.make(
                    app: app_model,
                    key_prefix: metric_tag_key_prefix,
                    key_name: 'index',
                    value: '999'
                  )

                  AppLabelModel.make(
                    app: app_model,
                    key_prefix: metric_tag_key_prefix,
                    key_name: 'ip',
                    value: '127.0.0.1'
                  )

                  AppLabelModel.make(
                    app: app_model,
                    key_prefix: metric_tag_key_prefix,
                    key_name: 'job',
                    value: 'potato farmer'
                  )
                end

                it 'do not get applied' do
                  expect(lrp.metric_tags['deployment']).to be_nil
                  expect(lrp.metric_tags['index']).to be_nil
                  expect(lrp.metric_tags['ip']).to be_nil
                  expect(lrp.metric_tags['job']).to be_nil
                end
              end
            end

            context 'when cc.custom_metric_tag_prefix_list is an empty list' do
              before do
                TestConfig.override(custom_metric_tag_prefix_list: [])
              end

              it 'app labels do not set custom tags' do
                expect(lrp.metric_tags['DatadogValue']).to be_nil
                expect(lrp.metric_tags['SomeotherValue']).to be_nil
              end
            end
          end

          context 'cpu weight with default max memory of 8G' do
            let(:min_cpu_proxy) { VCAP::CloudController::Config.config.get(:cpu_weight_min_memory) }
            let(:max_cpu_proxy) { VCAP::CloudController::Config.config.get(:cpu_weight_max_memory) }

            context 'when the memory limit is between the minimum and default maximum' do
              before { process.memory = (min_cpu_proxy + max_cpu_proxy) / 2 }

              it 'sets the cpu_weight to 100* value/max' do
                lrp = builder.build_app_lrp
                expect(lrp.cpu_weight).to eq(50)
              end
            end

            context 'when the memory limit is below the minimum' do
              before { process.memory = min_cpu_proxy - 1 }

              it 'sets the cpu_weight to 100*min/max' do
                lrp             = builder.build_app_lrp
                expected_weight = (100 * min_cpu_proxy / max_cpu_proxy).to_i
                expect(lrp.cpu_weight).to eq(expected_weight)
              end
            end

            context 'when the memory limit exceeds the default maximum (8192)' do
              before { process.memory = max_cpu_proxy + 1 }

              it 'sets the cpu_weight to 100' do
                lrp = builder.build_app_lrp
                expect(lrp.cpu_weight).to eq(100)
              end
            end
          end

          context 'cpu weight with max memory more than 8G' do
            let(:min_cpu_proxy) { VCAP::CloudController::Config.config.get(:cpu_weight_min_memory) }
            let(:max_cpu_proxy) { VCAP::CloudController::Config.config.get(:cpu_weight_max_memory) }

            before do
              TestConfig.override(cpu_weight_max_memory: 16_384)
            end

            context 'when the memory limit is between the default maximum (8G) and 16G of memory' do
              before { process.memory = 15_000 }

              it 'returns a percentage above 100' do
                lrp = builder.build_app_lrp
                expected_weight = (100 * process.memory) / BASE_WEIGHT
                expect(lrp.cpu_weight).to eq(expected_weight)
              end
            end

            context 'when memory limit is equal to 16G' do
              before { process.memory = BASE_WEIGHT * 2 }

              it 'sets the cpu_weight to 200' do
                lrp = builder.build_app_lrp
                expect(lrp.cpu_weight).to eq(200)
              end
            end

            context 'when memory limit is equal or above 16G' do
              before { process.memory = BASE_WEIGHT * 4 }

              it 'sets the cpu_weight to 200' do
                lrp = builder.build_app_lrp
                expect(lrp.cpu_weight).to eq(200)
              end
            end
          end

          context 'when the health_check_timeout is not set on process' do
            before do
              process.update(health_check_timeout: nil)
              config.set(:default_health_check_timeout, 12_345)
            end

            it 'falls back to the default located in the config' do
              lrp = builder.build_app_lrp
              expect(lrp.start_timeout_ms).to eq(12_345_000)
            end
          end

          context 'when the health check type is not set' do
            before do
              process.health_check_type = ''
            end

            it 'adds a port healthcheck action for backwards compatibility' do
              lrp = builder.build_app_lrp

              expect(lrp.monitor).to eq(expected_monitor_action)
            end
          end

          context 'when the health check type is set to "none"' do
            before do
              process.health_check_type = 'none'
            end

            it 'adds a port healthcheck action for backwards compatibility' do
              lrp = builder.build_app_lrp

              expect(lrp.monitor).to be_nil
            end
          end

          context 'when the docker_image is set' do
            it 'converts the docker_image url to a root_fs path' do
              lrp = builder.build_app_lrp

              expect(lrp.root_fs).to eq('docker_root_fs')
            end
          end

          context 'when a volume mount is provided' do
            let(:service_instance) { ManagedServiceInstance.make space: app_model.space }
            let(:multiple_volume_mounts) do
              [
                {
                  container_dir: '/data/images',
                  mode: 'r',
                  device_type: 'shared',
                  driver: 'cephfs',
                  device: {
                    volume_id: 'abc',
                    mount_config: {
                      key: 'value'
                    }
                  }
                },
                {
                  container_dir: '/data/scratch',
                  mode: 'rw',
                  device_type: 'shared',
                  driver: 'local',
                  device: {
                    volume_id: 'def',
                    mount_config: {}
                  }
                }
              ]
            end

            before do
              ServiceBinding.make(app: app_model, service_instance: service_instance, volume_mounts: multiple_volume_mounts)
            end

            it 'desires the mount' do
              lrp = builder.build_app_lrp
              expect(lrp.volume_mounts).to eq([
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver: 'cephfs',
                  container_dir: '/data/images',
                  mode: 'r',
                  shared: ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'abc', mount_config: { 'key' => 'value' }.to_json)
                ),
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver: 'local',
                  container_dir: '/data/scratch',
                  mode: 'rw',
                  shared: ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'def', mount_config: '')
                )
              ])
            end
          end

          describe 'ssh' do
            before do
              process.app.update(enable_ssh: true)
            end

            it 'includes the ssh port' do
              lrp = builder.build_app_lrp
              expect(desired_lrp_builder.ports).not_to include(2222)
              expect(lrp.ports).to include(2222)
            end

            it 'includes the lrp route' do
              lrp = builder.build_app_lrp
              expect(lrp.routes.routes['diego-ssh']).to eq(Oj.dump({
                                                                     container_port: 2222,
                                                                     private_key: ssh_key.private_key,
                                                                     host_fingerprint: ssh_key.fingerprint
                                                                   }))
            end
          end

          include_examples 'file-based service bindings'
        end
      end

      describe '#build_app_lrp_update' do
        let(:config) { Config.new({}) }
        let(:app_model) { AppModel.make(:buildpack, guid: 'app-guid', droplet: DropletModel.make(state: 'STAGED')) }
        let(:process) do
          process = ProcessModel.make(:process, instances: 7, app: app_model)
          process.this.update(updated_at: Time.at(2))
          process.reload
        end
        # the auto-generated proto clients use bytes type for routes, so an existing lrp response
        # will not turn routes into a ProtoRoutes object.
        # to simulate that in test we encode the ProtoRoutes object into bytes.
        let(:existing_lrp) do
          ::Diego::Bbs::Models::DesiredLRP.new(
            routes: ::Diego::Bbs::Models::ProtoRoutes.new(
              routes: existing_ssh_route
            )
          )
        end
        let(:existing_ssh_route) do
          {}
        end

        before do
          allow(VCAP::CloudController::IsolationSegmentSelector).to receive(:for_space).and_return('placement-tag')
        end

        it 'returns a DesiredLRPUpdate' do
          result = builder.build_app_lrp_update(existing_lrp)
          expect(result.instances).to eq(7)
          expect(result.annotation).to eq(Time.at(2).to_f.to_s)
          expect(result.metric_tags).to have_key('app_name')
          expect(result.metric_tags['app_name'].static).to eq(app_model.name)
        end

        describe 'routes' do
          before do
            routing_info = {
              'http_routes' => [
                {
                  'hostname' => 'potato.example.com',
                  'port' => 8080,
                  'router_group_guid' => 'potato-guid',
                  'protocol' => 'http1'
                },
                {
                  'hostname' => 'tomato.example.com',
                  'port' => 8080,
                  'router_group_guid' => 'tomato-guid',
                  'route_service_url' => 'https://potatosarebetter.example.com',
                  'protocol' => 'http2'
                }
              ],
              'tcp_routes' => [
                {
                  'router_group_guid' => 'im-a-guid',
                  'external_port' => 1234,
                  'container_port' => 4321
                },
                {
                  'router_group_guid' => 'im-probably-a-guid',
                  'external_port' => 789,
                  'container_port' => 987
                }
              ],
              'internal_routes' => [
                {
                  'hostname' => 'app-guid.apps.internal'
                }
              ]
            }

            routing_info_object = instance_double(Protocol::RoutingInfo)
            allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
            allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
          end

          it 'includes the correct routes' do
            expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
              routes: {
                'cf-router' => [
                  {
                    'hostnames' => ['potato.example.com'],
                    'port' => 8080,
                    'route_service_url' => nil,
                    'isolation_segment' => 'placement-tag',
                    'protocol' => 'http1'
                  },
                  {
                    'hostnames' => ['tomato.example.com'],
                    'port' => 8080,
                    'route_service_url' => 'https://potatosarebetter.example.com',
                    'isolation_segment' => 'placement-tag',
                    'protocol' => 'http2'
                  }
                ].to_json,
                'tcp-router' => [
                  {
                    'router_group_guid' => 'im-a-guid',
                    'external_port' => 1234,
                    'container_port' => 4321
                  },
                  {
                    'router_group_guid' => 'im-probably-a-guid',
                    'external_port' => 789,
                    'container_port' => 987
                  }
                ].to_json,
                'internal-router' => [
                  {
                    'hostname' => 'app-guid.apps.internal'
                  }
                ].to_json
              }
            )

            lrp_update = builder.build_app_lrp_update(existing_lrp)

            expect(lrp_update.routes).to eq(expected_routes)
          end

          context 'when there are no http routes' do
            before do
              routing_info = {
                'tcp_routes' => [
                  {
                    'router_group_guid' => 'im-a-guid',
                    'external_port' => 1234,
                    'container_port' => 4321
                  },
                  {
                    'router_group_guid' => 'im-probably-a-guid',
                    'external_port' => 789,
                    'container_port' => 987
                  }
                ],
                'internal_routes' => [
                  {
                    'hostname' => 'app-guid.apps.internal'
                  }
                ]
              }

              routing_info_object = instance_double(Protocol::RoutingInfo)
              allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
              allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
            end

            it 'includes empty cf-router entry' do
              expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                routes: {
                  'cf-router' => [].to_json,
                  'tcp-router' => [
                    {
                      'router_group_guid' => 'im-a-guid',
                      'external_port' => 1234,
                      'container_port' => 4321
                    },
                    {
                      'router_group_guid' => 'im-probably-a-guid',
                      'external_port' => 789,
                      'container_port' => 987
                    }
                  ].to_json,
                  'internal-router' => [
                    {
                      'hostname' => 'app-guid.apps.internal'
                    }
                  ].to_json
                }
              )

              lrp_update = builder.build_app_lrp_update(existing_lrp)

              expect(lrp_update.routes).to eq(expected_routes)
            end
          end

          context 'when there are no tcp routes' do
            before do
              routing_info = {
                'http_routes' => [
                  {
                    'hostname' => 'potato.example.com',
                    'port' => 8080,
                    'protocol' => 'http2'
                  },
                  {
                    'hostname' => 'tomato.example.com',
                    'port' => 8080,
                    'route_service_url' => 'https://potatosarebetter.example.com',
                    'protocol' => 'http1'
                  }
                ],
                'internal_routes' => [
                  {
                    'hostname' => 'app-guid.apps.internal'
                  }
                ]
              }

              routing_info_object = instance_double(Protocol::RoutingInfo)
              allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
              allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
            end

            it 'includes empty tcp-router entry' do
              expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                routes: {
                  'cf-router' => [
                    {
                      'hostnames' => ['potato.example.com'],
                      'port' => 8080,
                      'route_service_url' => nil,
                      'isolation_segment' => 'placement-tag',
                      'protocol' => 'http2'
                    },
                    {
                      'hostnames' => ['tomato.example.com'],
                      'port' => 8080,
                      'route_service_url' => 'https://potatosarebetter.example.com',
                      'isolation_segment' => 'placement-tag',
                      'protocol' => 'http1'
                    }
                  ].to_json,
                  'tcp-router' => [].to_json,
                  'internal-router' => [
                    {
                      'hostname' => 'app-guid.apps.internal'
                    }
                  ].to_json
                }
              )

              lrp_update = builder.build_app_lrp_update(existing_lrp)

              expect(lrp_update.routes).to eq(expected_routes)
            end
          end

          context 'when ssh routes are already present' do
            let(:existing_ssh_route) do
              { SSH_ROUTES_KEY => 'existing-data' }
            end

            it 'includes the ssh route unchanged' do
              lrp = builder.build_app_lrp_update(existing_lrp)
              expect(lrp.routes.routes[SSH_ROUTES_KEY]).to eq('existing-data')
            end
          end
        end
      end
    end
  end
end
