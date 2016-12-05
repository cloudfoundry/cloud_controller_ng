require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe AppRecipeBuilder do
      subject(:builder) { described_class.new }

      describe '#build_app_lrp' do
        let(:app_details_from_protocol) do
          json = MultiJson.load(protocol.desire_app_request(process, default_health_check_timeout))
          json['environment'] = environment_variables
          json.merge!(app_detail_overrides)
        end
        let(:app_detail_overrides) do
          { 'health_check_type' => 'port' }
        end

        let(:environment_variables) { ['name' => 'KEY', 'value' => 'running_value'] }
        let(:protocol) { Protocol.new }
        let(:default_health_check_timeout) { 24 }

        let(:lifecycle_type) { nil }
        let(:app_model) { AppModel.make(lifecycle_type, guid: 'banana-guid') }
        let(:package) { PackageModel.make(lifecycle_type, app: app_model) }
        let(:process) do
          process = ProcessModel.make(:process,
            app: app_model,
            state: 'STARTED',
            diego: true,
            guid: 'banana-guid',
            type: 'web',
            health_check_timeout: 12,
            instances: 21,
            memory: 128,
            disk_quota: 256,
            command: command,
            file_descriptors: 32,
          )
          process.this.update(updated_at: Time.at(2))
          process.reload
        end
        let(:command) { 'echo "hello"' }

        let(:route_without_service) { Route.make(space: process.space) }
        let(:route_with_service) do
          si = ManagedServiceInstance.make(:routing, space: process.space)
          r = Route.make(space: process.space)
          RouteBinding.make(route: r, service_instance: si, route_service_url: 'http://foobar.com')
          r
        end

        let(:expected_network) do
          ::Diego::Bbs::Models::Network.new(
            properties: [
              ::Diego::Bbs::Models::Network::PropertiesEntry.new(key: 'policy_group_id', value: process.guid),
              ::Diego::Bbs::Models::Network::PropertiesEntry.new(key: 'app_id', value: process.guid),
              ::Diego::Bbs::Models::Network::PropertiesEntry.new(key: 'space_id', value: process.space.guid),
              ::Diego::Bbs::Models::Network::PropertiesEntry.new(key: 'org_id', value: process.organization.guid),
            ]
          )
        end
        let(:expected_action_environment_variables) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'KEY', value: 'running_value'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '4444'),
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
              user: expected_action_user,
            )
          )
        end
        let(:expected_run_actions) { [expected_app_run_action] }
        let(:expected_monitor_action) do
          ::Diego::Bbs::Models::Action.new(
            timeout_action: ::Diego::Bbs::Models::TimeoutAction.new(
              timeout_ms: 30000,
              action: ::Diego::Bbs::Models::Action.new(
                parallel_action: ::Diego::Bbs::Models::ParallelAction.new(
                  actions: [
                    ::Diego::Bbs::Models::Action.new(
                      run_action: ::Diego::Bbs::Models::RunAction.new(
                        user: expected_action_user,
                        path: '/tmp/lifecycle/healthcheck',
                        args: ['-port=4444'],
                        resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                        log_source: HEALTH_LOG_SOURCE,
                        suppress_log_output: true,
                      )
                    ),
                    ::Diego::Bbs::Models::Action.new(
                      run_action: ::Diego::Bbs::Models::RunAction.new(
                        user: expected_action_user,
                        path: '/tmp/lifecycle/healthcheck',
                        args: ['-port=5555'],
                        resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                        log_source: HEALTH_LOG_SOURCE,
                        suppress_log_output: true,
                      )
                    )
                  ]
                )
              )
            )
          )
        end
        let(:expected_action_user) { 'root' }
        let(:expected_file_descriptor_limit) { 32 }
        let(:expected_cached_dependencies) do
          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: 'lifecycle-from',
              to: 'lifecycle-to',
              cache_key: 'lifecycle-key',
            ),
          ]
        end

        let(:lrp_builder_ports) { [4444, 5555] }

        let(:rule_dns_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol: 'udp',
            destinations: ['0.0.0.0/0'],
            ports: [53]
          )
        end
        let(:rule_http_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol: 'tcp',
            destinations: ['0.0.0.0/0'],
            ports: [80],
            log: true
          )
        end
        let(:rule_staging_specific) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol: 'tcp',
            destinations: ['0.0.0.0/0'],
            ports: [443],
            log: true
          )
        end
        let(:execution_metadata) { { user: execution_metadata_user }.to_json }
        let(:execution_metadata_user) { nil }

        before do
          [
            SecurityGroup.make(rules: [{ 'protocol' => 'udp', 'ports' => '53', 'destination' => '0.0.0.0/0' }]),
            SecurityGroup.make(rules: [{ 'protocol' => 'tcp', 'ports' => '80', 'destination' => '0.0.0.0/0', 'log' => true }]),
            SecurityGroup.make(rules: [{ 'protocol' => 'tcp', 'ports' => '443', 'destination' => '0.0.0.0/0', 'log' => true }]),
          ].each { |security_group| security_group.add_space(process.space) }

          RouteMappingModel.make(app: process.app, route: route_without_service, process_type: process.type, app_port: 1111)
          RouteMappingModel.make(app: process.app, route: route_with_service, process_type: process.type, app_port: 1111)

          app_model.update(droplet: droplet)
          process.current_droplet.execution_metadata = execution_metadata
        end

        context 'when the lifecycle_type is "buildpack"' do
          let(:lifecycle_type) { :buildpack }
          let(:droplet) do
            DropletModel.make(lifecycle_type,
              package: package,
              state: DropletModel::STAGED_STATE,
              execution_metadata: execution_metadata,
              droplet_hash: 'droplet-hash',
            )
          end
          let(:config) do
            {
              diego: {
                use_privileged_containers_for_running: false,
                lifecycle_bundles: {
                  'potato-stack' => 'some-uri'
                }
              }
            }
          end
          let(:expected_cached_dependencies) do
            [
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'lifecycle-from',
                to: 'lifecycle-to',
                cache_key: 'lifecycle-cache-key',
              ),
            ]
          end
          let(:expected_setup_action) { ::Diego::Bbs::Models::Action.new }
          let(:env_vars) { [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'foo', value: 'bar')] }

          let(:desired_lrp_builder) do
            instance_double(VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder,
              cached_dependencies: expected_cached_dependencies,
              root_fs: 'buildpack_root_fs',
              setup: expected_setup_action,
              global_environment_variables: env_vars,
              privileged?: false,
              ports: lrp_builder_ports,
            )
          end

          before do
            VCAP::CloudController::BuildpackLifecycleDataModel.make(
              app: app_model,
              buildpack: nil,
              stack: 'potato-stack',
            )

            allow(VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder).to receive(:new).and_return(desired_lrp_builder)
          end

          it 'creates a desired lrp' do
            lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
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
            expect(lrp.memory_mb).to eq(128)
            expect(lrp.metrics_guid).to eq(process.app.guid)
            expect(lrp.monitor).to eq(expected_monitor_action)
            expect(lrp.network).to eq(expected_network)
            expect(lrp.ports).to eq([4444, 5555])
            expect(lrp.process_guid).to eq(app_details_from_protocol['process_guid'])
            expect(lrp.root_fs).to eq('buildpack_root_fs')
            expect(lrp.setup).to eq(expected_setup_action)
            expect(lrp.start_timeout_ms).to eq(12 * 1000)
            expect(lrp.trusted_system_certificates_path).to eq(RUNNING_TRUSTED_SYSTEM_CERT_PATH)
          end

          xcontext 'monitor action should always be "vcap"'
          xcontext 'LegacyDownloadUser should always be "vcap"'

          context 'when a volume mount is provided' do
            let(:service_instance) { ManagedServiceInstance.make space: app_model.space }
            let(:multiple_volume_mounts) do
              [
                {
                  container_dir: '/data/images',
                  mode: 'r',
                  device_type: 'shared',
                  device: {
                    driver: 'cephfs',
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
                  device: {
                    driver: 'local',
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
              lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
              expect(lrp.volume_mounts).to eq([
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver: 'cephfs',
                  container_dir: '/data/images',
                  mode: 'r',
                  shared: ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'abc', mount_config: { 'key' => 'value' }.to_json),
                ),
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver: 'local',
                  container_dir: '/data/scratch',
                  mode: 'rw',
                  shared: ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'def', mount_config: ''),
                ),
              ])
            end
          end
        end

        context 'when the lifecycle_type is "docker"' do
          let(:config) { {} }
          let(:lifecycle_type) { :docker }
          let(:droplet) do
            DropletModel.make(:docker,
              package: package,
              state: DropletModel::STAGED_STATE,
              execution_metadata: execution_metadata,
              docker_receipt_image: 'docker-receipt-image',
            )
          end
          let(:old_expected_cached_dependencies) do
            [
              ::Diego::Bbs::Models::CachedDependency.new(
                from: 'http://file-server.com/v1/static/the/docker/lifecycle/path.tgz',
                to: '/tmp/lifecycle',
                cache_key: 'docker-lifecycle',
              ),
            ]
          end

          let(:desired_lrp_builder) do
            instance_double(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder,
              cached_dependencies: expected_cached_dependencies,
              root_fs: 'docker_root_fs',
              setup: nil,
              global_environment_variables: [],
              privileged?: false,
              ports: lrp_builder_ports,
            )
          end

          before do
            allow(VCAP::CloudController::Diego::Docker::DesiredLrpBuilder).to receive(:new).and_return(desired_lrp_builder)
          end

          it 'creates a desired lrp' do
            lrp = builder.build_app_lrp(config, process, app_details_from_protocol)

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
            expect(lrp.memory_mb).to eq(128)
            expect(lrp.metrics_guid).to eq(process.app.guid)
            expect(lrp.monitor).to eq(expected_monitor_action)
            expect(lrp.network).to eq(expected_network)
            expect(lrp.ports).to eq([4444, 5555])
            expect(lrp.privileged).to eq false
            expect(lrp.process_guid).to eq(app_details_from_protocol['process_guid'])
            expect(lrp.start_timeout_ms).to eq(12 * 1000)
            expect(lrp.trusted_system_certificates_path).to eq(RUNNING_TRUSTED_SYSTEM_CERT_PATH)
          end

          context 'cpu weight' do
            context 'when the memory limit is between the minimum and maximum' do
              before { process.memory = (MIN_CPU_PROXY + MAX_CPU_PROXY) / 2 }

              it 'sets the cpu_weight to 100* value/max' do
                lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
                expect(lrp.cpu_weight).to eq(50)
              end
            end

            context 'when the memory limit is below the minimum' do
              before { process.memory = MIN_CPU_PROXY - 1 }
              it 'sets the cpu_weight to 100*min/max' do
                lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
                expected_weight = (100 * MIN_CPU_PROXY / MAX_CPU_PROXY).to_i
                expect(lrp.cpu_weight).to eq(expected_weight)
              end
            end

            context 'when the memory limit exceeds the maximum' do
              before { process.memory = MAX_CPU_PROXY + 1 }
              it 'sets the cpu_weight to 100' do
                lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
                expect(lrp.cpu_weight).to eq(100)
              end
            end
          end

          context 'when log source is empty' do
            let(:app_detail_overrides) do
              { 'log_source' => nil }
            end
            let(:expected_app_run_action) do
              ::Diego::Bbs::Models::Action.new(
                run_action: ::Diego::Bbs::Models::RunAction.new(
                  path: '/tmp/lifecycle/launcher',
                  args: ['app', command, execution_metadata],
                  log_source: APP_LOG_SOURCE,
                  resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: 32),
                  env: expected_action_environment_variables,
                  user: 'root',
                )
              )
            end

            it 'uses APP' do
              lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
              expect(lrp.action).to eq(expected_action)
            end
          end

          context 'when the health check type is not set' do
            let(:app_detail_overrides) do
              { 'health_check_type' => '' }
            end

            it 'adds a port healthcheck action for backwards compatibility' do
              lrp = builder.build_app_lrp(config, process, app_details_from_protocol)

              expect(lrp.monitor).to eq(expected_monitor_action)
            end
          end

          context 'when the health check type is set to "none"' do
            let(:app_detail_overrides) do
              { 'health_check_type' => 'none' }
            end

            it 'adds a port healthcheck action for backwards compatibility' do
              lrp = builder.build_app_lrp(config, process, app_details_from_protocol)

              expect(lrp.monitor).to eq(nil)
            end
          end

          context 'when the docker_image is set' do
            it 'converts the docker_image url to a root_fs path' do
              lrp = builder.build_app_lrp(config, process, app_details_from_protocol)

              expect(lrp.root_fs).to eq('docker_root_fs')
            end
          end

          context 'when the execution metadata has a specified user' do
            let(:expected_action_user) { 'foobar' }
            let(:execution_metadata_user) { 'foobar' }

            it 'uses the user from the execution metadata' do
              lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
              expect(lrp.action).to eq(expected_action)
              expect(lrp.monitor).to eq(expected_monitor_action)
            end
          end

          context 'when FileDescriptors is 0' do
            before { process.file_descriptors = 0 }
            let(:expected_file_descriptor_limit) { DEFAULT_FILE_DESCRIPTOR_LIMIT }

            it 'uses the default File Descriptor Limit on the first run actions resource limits' do
              lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
              expect(lrp.action).to eq(expected_action)
              expect(lrp.monitor).to eq(expected_monitor_action)
            end
          end

          xcontext 'when ssh is allowed' do
            before { process.allow_ssh = true }
            let(:expected_diego_sshd_run_action) do
              ::Diego::Bbs::Models::Action.new(
                run_action: ::Diego::Bbs::Models::RunAction.new(
                  path: '/tmp/lifecycle/diego-sshd',
                  args: [ # TODO: generate rsa keypair like "code.cloudfoundry.org/diego-ssh/keys"
                    '-address=0.0.0.0:1111',
                    '-hostKey=pem-host-private-key',
                    '-authorizedKey=authorized-user-key',
                    '-inheritDaemonEnv',
                    '-logLevel=fatal',
                  ],
                  resource_limits: expected_app_run_action.resource_limits,
                  env: expected_app_run_action.env,
                  user: expected_app_run_action.user,
                )
              )
            end
            let(:expected_run_actions) { [expected_app_run_action, expected_diego_sshd_run_action] }

            it 'adds the default ssh port to the list of ports'
          end

          context 'when a volume mount is provided' do
            let(:service_instance) { ManagedServiceInstance.make space: app_model.space }
            let(:multiple_volume_mounts) do
              [
                {
                  container_dir: '/data/images',
                  mode: 'r',
                  device_type: 'shared',
                  device: {
                    driver: 'cephfs',
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
                  device: {
                    driver: 'local',
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
              lrp = builder.build_app_lrp(config, process, app_details_from_protocol)
              expect(lrp.volume_mounts).to eq([
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver: 'cephfs',
                  container_dir: '/data/images',
                  mode: 'r',
                  shared: ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'abc', mount_config: { 'key' => 'value' }.to_json),
                ),
                ::Diego::Bbs::Models::VolumeMount.new(
                  driver: 'local',
                  container_dir: '/data/scratch',
                  mode: 'rw',
                  shared: ::Diego::Bbs::Models::SharedDevice.new(volume_id: 'def', mount_config: ''),
                ),
              ])
            end
          end
        end
      end
    end
  end
end
