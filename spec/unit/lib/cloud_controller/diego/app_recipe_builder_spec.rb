require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe AppRecipeBuilder do
      subject(:builder) do
        described_class.new(
          config:  config,
          process: process,
          ssh_key: ssh_key
        )
      end

      let(:ssh_key) { SSHKey.new }

      describe '#build_app_lrp' do
        let(:environment_variables) { ['name' => 'KEY', 'value' => 'running_value'] }
        before do
          environment = instance_double(Environment)
          allow(Environment).to receive(:new).with(process, {}).and_return(environment)
          allow(environment).to receive(:as_json).and_return(environment_variables)
        end

        let(:port_environment_variables) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '4444'),
          ]
        end

        let(:lifecycle_type) { nil }
        let(:app_model) { AppModel.make(lifecycle_type, guid: 'app-guid', droplet: DropletModel.make(state: 'STAGED'), enable_ssh: false) }
        let(:package) { PackageModel.make(lifecycle_type, app: app_model) }
        let(:process) do
          process = ProcessModel.make(:process,
            app:                  app_model,
            state:                'STARTED',
            diego:                true,
            guid:                 'process-guid',
            type:                 'web',
            health_check_timeout: 12,
            instances:            21,
            memory:               128,
            disk_quota:           256,
            command:              command,
            file_descriptors:     32,
            health_check_type:    'port',
            enable_ssh:           false
          )
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

        let(:expected_network) do
          ::Diego::Bbs::Models::Network.new(
            properties: [
              ::Diego::Bbs::Models::Network::PropertiesEntry.new(key: 'policy_group_id', value: app_model.guid),
              ::Diego::Bbs::Models::Network::PropertiesEntry.new(key: 'app_id', value: app_model.guid),
              ::Diego::Bbs::Models::Network::PropertiesEntry.new(key: 'space_id', value: app_model.space.guid),
              ::Diego::Bbs::Models::Network::PropertiesEntry.new(key: 'org_id', value: app_model.organization.guid),
            ]
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
              path:            '/tmp/lifecycle/launcher',
              args:            ['app', command, execution_metadata],
              log_source:      'APP/PROC/WEB',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
              env:             expected_action_environment_variables,
              user:            'lrp-action-user',
            )
          )
        end
        let(:expected_run_actions) { [expected_app_run_action] }
        let(:expected_monitor_action) do
          ::Diego::Bbs::Models::Action.new(
            timeout_action: ::Diego::Bbs::Models::TimeoutAction.new(
              timeout_ms: 600000,
              action:     ::Diego::Bbs::Models::Action.new(
                parallel_action: ::Diego::Bbs::Models::ParallelAction.new(
                  actions: [
                    ::Diego::Bbs::Models::Action.new(
                      run_action: ::Diego::Bbs::Models::RunAction.new(
                        user:                'lrp-action-user',
                        path:                '/tmp/lifecycle/healthcheck',
                        args:                ['-port=4444'],
                        resource_limits:     ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                        log_source:          HEALTH_LOG_SOURCE,
                        suppress_log_output: true,
                      )
                    ),
                    ::Diego::Bbs::Models::Action.new(
                      run_action: ::Diego::Bbs::Models::RunAction.new(
                        user:                'lrp-action-user',
                        path:                '/tmp/lifecycle/healthcheck',
                        args:                ['-port=5555'],
                        resource_limits:     ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                        log_source:          HEALTH_LOG_SOURCE,
                        suppress_log_output: true,
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
              from:      'lifecycle-from',
              to:        'lifecycle-to',
              cache_key: 'lifecycle-key',
            ),
          ]
        end

        let(:expected_certificate_properties) do
          ::Diego::Bbs::Models::CertificateProperties.new(
            organizational_unit: ["app:#{process.app.guid}"],
          )
        end

        let(:lrp_builder_ports) { [4444, 5555] }

        let(:rule_dns_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     'udp',
            destinations: ['0.0.0.0/0'],
            ports:        [53],
            annotations:  ['security_group_id:guid1']
          )
        end
        let(:rule_http_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     'tcp',
            destinations: ['0.0.0.0/0'],
            ports:        [80],
            log:          true,
            annotations:  ['security_group_id:guid2']
          )
        end
        let(:rule_staging_specific) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     'tcp',
            destinations: ['0.0.0.0/0'],
            ports:        [443],
            log: true,
            annotations: ['security_group_id:guid3']
          )
        end
        let(:execution_metadata) { { user: execution_metadata_user }.to_json }
        let(:execution_metadata_user) { nil }

        before do
          [
            SecurityGroup.make(guid: 'guid1', rules: [{ 'protocol' => 'udp', 'ports' => '53', 'destination' => '0.0.0.0/0' }]),
            SecurityGroup.make(guid: 'guid2', rules: [{ 'protocol' => 'tcp', 'ports' => '80', 'destination' => '0.0.0.0/0', 'log' => true }]),
            SecurityGroup.make(guid: 'guid3', rules: [{ 'protocol' => 'tcp', 'ports' => '443', 'destination' => '0.0.0.0/0', 'log' => true }]),
          ].each { |security_group| security_group.add_space(process.space) }

          RouteMappingModel.make(app: process.app, route: route_without_service, process_type: process.type, app_port: 1111)
          RouteMappingModel.make(app: process.app, route: route_with_service, process_type: process.type, app_port: 1111)

          app_model.update(droplet: droplet)
          allow(VCAP::CloudController::IsolationSegmentSelector).to receive(:for_space).and_return('placement-tag')
          process.current_droplet.execution_metadata = execution_metadata
        end

        context 'when the lifecycle_type is "buildpack"' do
          let(:lifecycle_type) { :buildpack }
          let(:droplet) do
            DropletModel.make(lifecycle_type,
              package:            package,
              state:              DropletModel::STAGED_STATE,
              execution_metadata: execution_metadata,
              droplet_hash:       'droplet-hash',
            )
          end
          let(:config) do
            {
              diego: {
                use_privileged_containers_for_running: false,
                lifecycle_bundles:                     {
                  'potato-stack' => 'some-uri'
                },
                pid_limit:                             100,
              }
            }
          end
          let(:expected_cached_dependencies) do
            [
              ::Diego::Bbs::Models::CachedDependency.new(
                from:      'lifecycle-from',
                to:        'lifecycle-to',
                cache_key: 'lifecycle-cache-key',
              ),
            ]
          end
          let(:expected_setup_action) { ::Diego::Bbs::Models::Action.new }
          let(:env_vars) { [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'foo', value: 'bar')] }

          let(:desired_lrp_builder) do
            instance_double(VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder,
              cached_dependencies:          expected_cached_dependencies,
              root_fs:                      'buildpack_root_fs',
              setup:                        expected_setup_action,
              global_environment_variables: env_vars,
              privileged?:                  false,
              ports:                        lrp_builder_ports,
              port_environment_variables:   port_environment_variables,
              action_user:                  'lrp-action-user',
              start_command:                command,
            )
          end

          before do
            VCAP::CloudController::BuildpackLifecycleDataModel.make(
              app:        app_model,
              buildpacks: nil,
              stack:      'potato-stack',
            )

            allow(VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder).to receive(:new).and_return(desired_lrp_builder)
          end

          it 'creates a desired lrp' do
            lrp = builder.build_app_lrp
            expect(lrp.action).to eq(expected_action)
            expect(lrp.annotation).to eq(Time.at(2).to_f.to_s)
            expect(lrp.cached_dependencies).to eq(expected_cached_dependencies)
            expect(lrp.disk_mb).to eq(256)
            expect(lrp.domain).to eq(APP_LRP_DOMAIN)
            expect(lrp.egress_rules).to match_array([
              rule_dns_everywhere,
              rule_http_everywhere,
              rule_staging_specific,
            ])
            expect(lrp.environment_variables).to match_array(
              [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'foo', value: 'bar')]
            )
            expect(lrp.instances).to eq(21)
            expect(lrp.legacy_download_user).to eq('root')
            expect(lrp.log_guid).to eq(process.app.guid)
            expect(lrp.log_source).to eq(LRP_LOG_SOURCE)
            expect(lrp.max_pids).to eq(100)
            expect(lrp.memory_mb).to eq(128)
            expect(lrp.metrics_guid).to eq(process.app.guid)
            expect(lrp.monitor).to eq(expected_monitor_action)
            expect(lrp.network).to eq(expected_network)
            expect(lrp.ports).to eq([4444, 5555])
            expect(lrp.process_guid).to eq(ProcessGuid.from_process(process))
            expect(lrp.root_fs).to eq('buildpack_root_fs')
            expect(lrp.setup).to eq(expected_setup_action)
            expect(lrp.start_timeout_ms).to eq(12 * 1000)
            expect(lrp.trusted_system_certificates_path).to eq(RUNNING_TRUSTED_SYSTEM_CERT_PATH)
            expect(lrp.PlacementTags).to eq(['placement-tag'])
            expect(lrp.certificate_properties).to eq(expected_certificate_properties)
          end

          context 'when a volume mount is provided' do
            let(:service_instance) { ManagedServiceInstance.make space: app_model.space }
            let(:multiple_volume_mounts) do
              [
                {
                  container_dir: '/data/images',
                  mode:          'r',
                  device_type:   'shared',
                  driver:        'cephfs',
                  device:        {
                    volume_id:    'abc',
                    mount_config: {
                      key: 'value'
                    }
                  }
                },
                {
                  container_dir: '/data/scratch',
                  mode:          'rw',
                  device_type:   'shared',
                  driver:        'local',
                  device:        {
                    volume_id:    'def',
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
                  driver:        'cephfs',
                  container_dir: '/data/images',
                  mode:          'r',
                  shared:        ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'abc', mount_config: { 'key' => 'value' }.to_json),
                ),
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver:        'local',
                  container_dir: '/data/scratch',
                  mode:          'rw',
                  shared:        ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'def', mount_config: ''),
                ),
              ])
            end
          end

          context 'when FileDescriptors is 0' do
            before { process.file_descriptors = 0 }
            let(:expected_file_descriptor_limit) { DEFAULT_FILE_DESCRIPTOR_LIMIT }

            it 'uses the default File Descriptor Limit on the first run actions resource limits' do
              lrp = builder.build_app_lrp
              expect(lrp.action).to eq(expected_action)
              expect(lrp.monitor).to eq(expected_monitor_action)
            end
          end

          context 'healthcheck' do
            context 'when the health_check_timeout is not set on process' do
              before do
                process.update(health_check_timeout: nil)
                config.merge!(default_health_check_timeout: 12345)
              end

              it 'falls back to the default located in the config' do
                lrp = builder.build_app_lrp
                expect(lrp.start_timeout_ms).to eq(12345000)
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

                expect(lrp.monitor).to eq(nil)
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
              end
            end

            context 'when the health check type is set to "http"' do
              before do
                process.health_check_type          = 'http'
                process.health_check_http_endpoint = 'http-endpoint'
              end

              let(:expected_monitor_action) do
                ::Diego::Bbs::Models::Action.new(
                  timeout_action: ::Diego::Bbs::Models::TimeoutAction.new(
                    timeout_ms: 600000,
                    action:     ::Diego::Bbs::Models::Action.new(
                      parallel_action: ::Diego::Bbs::Models::ParallelAction.new(
                        actions: [
                          ::Diego::Bbs::Models::Action.new(
                            run_action: ::Diego::Bbs::Models::RunAction.new(
                              user:                'lrp-action-user',
                              path:                '/tmp/lifecycle/healthcheck',
                              args:                ['-port=4444', '-uri=http-endpoint'],
                              resource_limits:     ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                              log_source:          HEALTH_LOG_SOURCE,
                              suppress_log_output: true,
                            )
                          ),
                          ::Diego::Bbs::Models::Action.new(
                            run_action: ::Diego::Bbs::Models::RunAction.new(
                              user:                'lrp-action-user',
                              path:                '/tmp/lifecycle/healthcheck',
                              args:                ['-port=5555'],
                              resource_limits:     ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                              log_source:          HEALTH_LOG_SOURCE,
                              suppress_log_output: true,
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
              end

              it 'keeps a TCP health check definition for other ports' do
                lrp       = builder.build_app_lrp
                tcp_check = lrp.check_definition.checks.second.tcp_check
                expect(tcp_check.port).to eq(5555)
              end
            end

            context 'when the health check type is not recognized' do
              before do
                process.health_check_type = 'foobar'
              end

              it 'adds a port healthcheck action for backwards compatibility' do
                lrp = builder.build_app_lrp

                expect(lrp.monitor).to eq(nil)
              end

              it 'does not add healthcheck definitions' do
                lrp              = builder.build_app_lrp
                check_definition = lrp.check_definition
                expect(check_definition).to be_nil
              end
            end
          end

          describe 'routes' do
            before do
              routing_info = {
                'http_routes' => [
                  {
                    'hostname' => 'potato.example.com',
                    'port'     => 8080,
                  },
                  {
                    'hostname'          => 'tomato.example.com',
                    'port'              => 8080,
                    'route_service_url' => 'https://potatosarebetter.example.com'
                  }
                ],
                'tcp_routes' => [
                  {
                    'router_group_guid' => 'im-a-guid',
                    'external_port'     => 1234,
                    'container_port'    => 4321
                  },
                  {
                    'router_group_guid' => 'im-probably-a-guid',
                    'external_port'     => 789,
                    'container_port'    => 987
                  },
                ]
              }

              routing_info_object = instance_double(Protocol::RoutingInfo)
              allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
              allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
            end

            it 'includes the correct routes' do
              expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                routes: [
                  ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                    key:   'cf-router',
                    value: [
                      {
                               'hostnames'         => ['potato.example.com'],
                               'port'              => 8080,
                               'route_service_url' => nil,
                               'isolation_segment' => 'placement-tag',
                             },
                      {
                        'hostnames'         => ['tomato.example.com'],
                        'port'              => 8080,
                        'route_service_url' => 'https://potatosarebetter.example.com',
                        'isolation_segment' => 'placement-tag',
                      }
                    ].to_json
                  ),
                  ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                    key:   'tcp-router',
                    value: [
                      {
                        'router_group_guid' => 'im-a-guid',
                        'external_port'     => 1234,
                        'container_port'    => 4321
                      },
                      {
                        'router_group_guid' => 'im-probably-a-guid',
                        'external_port'     => 789,
                        'container_port'    => 987
                      }
                    ].to_json
                  )
                ]
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
                      'external_port'     => 1234,
                      'container_port'    => 4321
                    },
                    {
                      'router_group_guid' => 'im-probably-a-guid',
                      'external_port'     => 789,
                      'container_port'    => 987
                    },
                  ]
                }

                routing_info_object = instance_double(Protocol::RoutingInfo)
                allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
                allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
              end

              it 'includes empty cf-router entry' do
                expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                  routes: [
                    ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                      key:   'cf-router',
                      value: [].to_json
                    ),
                    ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                      key:   'tcp-router',
                      value: [
                        {
                          'router_group_guid' => 'im-a-guid',
                          'external_port'     => 1234,
                          'container_port'    => 4321
                        },
                        {
                          'router_group_guid' => 'im-probably-a-guid',
                          'external_port'     => 789,
                          'container_port'    => 987
                        }
                      ].to_json
                    )
                  ]
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
                      'port'     => 8080
                    },
                    {
                      'hostname'          => 'tomato.example.com',
                      'port'              => 8080,
                      'route_service_url' => 'https://potatosarebetter.example.com'
                    }
                  ]
                }

                routing_info_object = instance_double(Protocol::RoutingInfo)
                allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
                allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
              end

              it 'includes empty tcp-router entry' do
                expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                  routes: [
                    ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                      key:   'cf-router',
                      value: [
                        {
                                 'hostnames'         => ['potato.example.com'],
                                 'port'              => 8080,
                                 'route_service_url' => nil,
                                 'isolation_segment' => 'placement-tag',
                               },
                        {
                          'hostnames'         => ['tomato.example.com'],
                          'port'              => 8080,
                          'route_service_url' => 'https://potatosarebetter.example.com',
                          'isolation_segment' => 'placement-tag',
                        }
                      ].to_json
                    ),
                    ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                      key:   'tcp-router',
                      value: [].to_json
                    )
                  ]
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
              expect(lrp.ports).to include(2222)
            end

            it 'includes the lrp route' do
              lrp = builder.build_app_lrp
              expect(lrp.routes.routes).to include(
                ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                  key:   'diego-ssh',
                  value: MultiJson.dump({
                    container_port:   2222,
                    private_key:      ssh_key.private_key,
                    host_fingerprint: ssh_key.fingerprint
                  })
                )
              )
            end

            it 'includes the ssh daemon run action' do
              lrp = builder.build_app_lrp

              actions = lrp.action.codependent_action.actions.map(&:run_action)
              expect(actions).to include(
                ::Diego::Bbs::Models::RunAction.new(
                  user:            'lrp-action-user',
                  path:            '/tmp/lifecycle/diego-sshd',
                  args:            [
                    '-address=0.0.0.0:2222',
                    "-hostKey=#{ssh_key.private_key}",
                    "-authorizedKey=#{ssh_key.authorized_key}",
                    '-inheritDaemonEnv',
                    '-logLevel=fatal',
                  ],
                  resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                  env:             expected_action_environment_variables,
                  log_source: 'CELL/SSHD',
                )
              )
            end
          end

          context 'when the same builder is used twice' do
            it 'should build the same app lrp' do
              lrp = builder.build_app_lrp
              expect(lrp.action).to eq(expected_action)
              lrp2 = builder.build_app_lrp
              expect(lrp2.action).to eq(expected_action)
            end
          end
        end

        context 'when the lifecycle_type is "docker"' do
          let(:config) do
            {
              diego: {
                pid_limit: 100,
              }
            }
          end
          let(:lifecycle_type) { :docker }
          let(:package) { PackageModel.make(lifecycle_type, app: app_model) }
          let(:droplet) do
            DropletModel.make(:docker,
              package:                 package,
              state:                   DropletModel::STAGED_STATE,
              execution_metadata:      execution_metadata,
              docker_receipt_image:    'docker-receipt-image',
              docker_receipt_username: 'dockeruser',
              docker_receipt_password: 'dockerpass',
            )
          end
          let(:old_expected_cached_dependencies) do
            [
              ::Diego::Bbs::Models::CachedDependency.new(
                from:      'http://file-server.com/v1/static/the/docker/lifecycle/path.tgz',
                to:        '/tmp/lifecycle',
                cache_key: 'docker-lifecycle',
              ),
            ]
          end

          let(:desired_lrp_builder) do
            instance_double(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder,
              cached_dependencies:          expected_cached_dependencies,
              root_fs:                      'docker_root_fs',
              setup:                        nil,
              global_environment_variables: [],
              privileged?:                  false,
              ports:                        lrp_builder_ports,
              port_environment_variables:   port_environment_variables,
              action_user:                  'lrp-action-user',
              start_command:                command,
            )
          end

          before do
            allow(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder).to receive(:new).and_return(desired_lrp_builder)
          end

          it 'creates a desired lrp' do
            lrp = builder.build_app_lrp

            expect(lrp.action).to eq(expected_action)
            expect(lrp.annotation).to eq(Time.at(2).to_f.to_s)
            expect(lrp.cached_dependencies).to eq(expected_cached_dependencies)
            expect(lrp.instances).to eq(21)
            expect(lrp.disk_mb).to eq(256)
            expect(lrp.domain).to eq(APP_LRP_DOMAIN)
            expect(lrp.egress_rules).to match_array([
              rule_dns_everywhere,
              rule_http_everywhere,
              rule_staging_specific,
            ])
            expect(lrp.environment_variables).to eq([])
            expect(lrp.legacy_download_user).to eq('root')
            expect(lrp.log_source).to eq(LRP_LOG_SOURCE)
            expect(lrp.log_guid).to eq(process.app.guid)
            expect(lrp.max_pids).to eq(100)
            expect(lrp.memory_mb).to eq(128)
            expect(lrp.metrics_guid).to eq(process.app.guid)
            expect(lrp.monitor).to eq(expected_monitor_action)
            expect(lrp.network).to eq(expected_network)
            expect(lrp.ports).to eq([4444, 5555])
            expect(lrp.privileged).to eq false
            expect(lrp.process_guid).to eq(ProcessGuid.from_process(process))
            expect(lrp.start_timeout_ms).to eq(12 * 1000)
            expect(lrp.trusted_system_certificates_path).to eq(RUNNING_TRUSTED_SYSTEM_CERT_PATH)
            expect(lrp.PlacementTags).to eq(['placement-tag'])
            expect(lrp.certificate_properties).to eq(expected_certificate_properties)
            expect(lrp.image_username).to eq('dockeruser')
            expect(lrp.image_password).to eq('dockerpass')
          end

          context 'cpu weight' do
            context 'when the memory limit is between the minimum and maximum' do
              before { process.memory = (MIN_CPU_PROXY + MAX_CPU_PROXY) / 2 }

              it 'sets the cpu_weight to 100* value/max' do
                lrp = builder.build_app_lrp
                expect(lrp.cpu_weight).to eq(50)
              end
            end

            context 'when the memory limit is below the minimum' do
              before { process.memory = MIN_CPU_PROXY - 1 }
              it 'sets the cpu_weight to 100*min/max' do
                lrp             = builder.build_app_lrp
                expected_weight = (100 * MIN_CPU_PROXY / MAX_CPU_PROXY).to_i
                expect(lrp.cpu_weight).to eq(expected_weight)
              end
            end

            context 'when the memory limit exceeds the maximum' do
              before { process.memory = MAX_CPU_PROXY + 1 }
              it 'sets the cpu_weight to 100' do
                lrp = builder.build_app_lrp
                expect(lrp.cpu_weight).to eq(100)
              end
            end
          end

          context 'when the health_check_timeout is not set on process' do
            before do
              process.update(health_check_timeout: nil)
              config.merge!(default_health_check_timeout: 12345)
            end

            it 'falls back to the default located in the config' do
              lrp = builder.build_app_lrp
              expect(lrp.start_timeout_ms).to eq(12345000)
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

              expect(lrp.monitor).to eq(nil)
            end
          end

          context 'when the docker_image is set' do
            it 'converts the docker_image url to a root_fs path' do
              lrp = builder.build_app_lrp

              expect(lrp.root_fs).to eq('docker_root_fs')
            end
          end

          context 'when FileDescriptors is 0' do
            before { process.file_descriptors = 0 }
            let(:expected_file_descriptor_limit) { DEFAULT_FILE_DESCRIPTOR_LIMIT }

            it 'uses the default File Descriptor Limit on the first run actions resource limits' do
              lrp = builder.build_app_lrp
              expect(lrp.action).to eq(expected_action)
              expect(lrp.monitor).to eq(expected_monitor_action)
            end
          end

          context 'when a volume mount is provided' do
            let(:service_instance) { ManagedServiceInstance.make space: app_model.space }
            let(:multiple_volume_mounts) do
              [
                {
                  container_dir: '/data/images',
                  mode:          'r',
                  device_type:   'shared',
                  driver:        'cephfs',
                  device:        {
                    volume_id:    'abc',
                    mount_config: {
                      key: 'value'
                    }
                  }
                },
                {
                  container_dir: '/data/scratch',
                  mode:          'rw',
                  device_type:   'shared',
                  driver:        'local',
                  device:        {
                    volume_id:    'def',
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
                  driver:        'cephfs',
                  container_dir: '/data/images',
                  mode:          'r',
                  shared:        ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'abc', mount_config: { 'key' => 'value' }.to_json),
                ),
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver:        'local',
                  container_dir: '/data/scratch',
                  mode:          'rw',
                  shared:        ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'def', mount_config: ''),
                ),
              ])
            end
          end
        end
      end

      describe '#build_app_lrp_update' do
        let(:config) { {} }
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
              routes: [existing_ssh_route]
            )
          )
        end
        let(:existing_ssh_route) { nil }

        before do
          allow(VCAP::CloudController::IsolationSegmentSelector).to receive(:for_space).and_return('placement-tag')
        end

        it 'returns a DesiredLRPUpdate' do
          result = builder.build_app_lrp_update(existing_lrp)
          expect(result.instances).to eq(7)
          expect(result.annotation).to eq(Time.at(2).to_f.to_s)
        end

        describe 'routes' do
          before do
            routing_info = {
              'http_routes' => [
                {
                  'hostname'          => 'potato.example.com',
                  'port'              => 8080,
                  'router_group_guid' => 'potato-guid'
                },
                {
                  'hostname'          => 'tomato.example.com',
                  'port'              => 8080,
                  'router_group_guid' => 'tomato-guid',
                  'route_service_url' => 'https://potatosarebetter.example.com'
                }
              ],
              'tcp_routes' => [
                {
                  'router_group_guid' => 'im-a-guid',
                  'external_port'     => 1234,
                  'container_port'    => 4321
                },
                {
                  'router_group_guid' => 'im-probably-a-guid',
                  'external_port'     => 789,
                  'container_port'    => 987
                },
              ]
            }

            routing_info_object = instance_double(Protocol::RoutingInfo)
            allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
            allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
          end

          it 'includes the correct routes' do
            expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
              routes: [
                ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                  key:   'cf-router',
                  value: [
                    {
                             'hostnames'         => ['potato.example.com'],
                             'port'              => 8080,
                             'route_service_url' => nil,
                             'isolation_segment' => 'placement-tag',
                           },
                    {
                      'hostnames'         => ['tomato.example.com'],
                      'port'              => 8080,
                      'route_service_url' => 'https://potatosarebetter.example.com',
                      'isolation_segment' => 'placement-tag',
                    }
                  ].to_json
                ),
                ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                  key:   'tcp-router',
                  value: [
                    {
                      'router_group_guid' => 'im-a-guid',
                      'external_port'     => 1234,
                      'container_port'    => 4321
                    },
                    {
                      'router_group_guid' => 'im-probably-a-guid',
                      'external_port'     => 789,
                      'container_port'    => 987
                    }
                  ].to_json
                )
              ]
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
                    'external_port'     => 1234,
                    'container_port'    => 4321
                  },
                  {
                    'router_group_guid' => 'im-probably-a-guid',
                    'external_port'     => 789,
                    'container_port'    => 987
                  },
                ]
              }

              routing_info_object = instance_double(Protocol::RoutingInfo)
              allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
              allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
            end

            it 'includes empty cf-router entry' do
              expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                routes: [
                  ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                    key:   'cf-router',
                    value: [].to_json
                  ),
                  ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                    key:   'tcp-router',
                    value: [
                      {
                        'router_group_guid' => 'im-a-guid',
                        'external_port'     => 1234,
                        'container_port'    => 4321
                      },
                      {
                        'router_group_guid' => 'im-probably-a-guid',
                        'external_port'     => 789,
                        'container_port'    => 987
                      }
                    ].to_json
                  )
                ]
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
                    'port'     => 8080
                  },
                  {
                    'hostname'          => 'tomato.example.com',
                    'port'              => 8080,
                    'route_service_url' => 'https://potatosarebetter.example.com'
                  }
                ]
              }

              routing_info_object = instance_double(Protocol::RoutingInfo)
              allow(Protocol::RoutingInfo).to receive(:new).with(process).and_return(routing_info_object)
              allow(routing_info_object).to receive(:routing_info).and_return(routing_info)
            end

            it 'includes empty tcp-router entry' do
              expected_routes = ::Diego::Bbs::Models::ProtoRoutes.new(
                routes: [
                  ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                    key:   'cf-router',
                    value: [
                      {
                               'hostnames'         => ['potato.example.com'],
                               'port'              => 8080,
                               'route_service_url' => nil,
                               'isolation_segment' => 'placement-tag',
                             },
                      {
                        'hostnames'         => ['tomato.example.com'],
                        'port'              => 8080,
                        'route_service_url' => 'https://potatosarebetter.example.com',
                        'isolation_segment' => 'placement-tag',
                      }
                    ].to_json
                  ),
                  ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                    key:   'tcp-router',
                    value: [].to_json
                  )
                ]
              )

              lrp_update = builder.build_app_lrp_update(existing_lrp)

              expect(lrp_update.routes).to eq(expected_routes)
            end
          end

          context 'when ssh routes are already present' do
            let(:existing_ssh_route) do
              ::Diego::Bbs::Models::ProtoRoutes::RoutesEntry.new(
                key:   SSH_ROUTES_KEY,
                value: 'existing-data'
              )
            end

            it 'includes the ssh route unchanged' do
              lrp = builder.build_app_lrp_update(existing_lrp)
              expect(lrp.routes.routes).to include(existing_ssh_route)
            end
          end
        end
      end
    end
  end
end
