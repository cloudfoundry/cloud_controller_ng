require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe RecipeBuilder do
      subject(:recipe_builder) { RecipeBuilder.new }

      describe '#build_staging_task' do
        let(:app) { AppModel.make(guid: 'banana-guid') }
        let(:staging_details) do
          Diego::StagingDetails.new.tap do |details|
            details.droplet               = droplet
            details.package               = package
            details.environment_variables = { 'nightshade_fruit' => 'potato' }
            details.staging_memory_in_mb  = 42
            details.staging_disk_in_mb    = 51
            details.start_after_staging   = true
          end
        end
        let(:config) do
          {
            skip_cert_verify:          false,
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
            },
            diego:                     {
              temporary_local_staging:               true,
              use_privileged_containers_for_staging: false,
              cc_uploader_url:                       'http://cc-uploader.example.com',
              file_server_url:                       'http://file-server.example.com',
              stager_url:                            'http://stager.example.com',
              docker_staging_stack:                  'docker-stack',
              insecure_docker_registry_list:         ['registry-1', 'registry-2'],
              lifecycle_bundles:                     {
                'buildpack/potato-stack': 'my_potato_life.tgz',
                'buildpack/valid_url': 'http://example.com',
                'buildpack/invalid_url': 'ftp://example.com',
                'docker': 'docker_stack.tgz'
              },
            },
          }
        end
        let(:internal_service_hostname) { 'internal.awesome.sauce' }
        let(:external_port) { '7777' }
        let(:user) { 'user' }
        let(:password) { 'password' }
        let(:rule_dns_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     'udp',
            destinations: ['0.0.0.0/0'],
            ports:        [53]
          )
        end
        let(:rule_http_everywhere) do
          ::Diego::Bbs::Models::SecurityGroupRule.new(
            protocol:     'tcp',
            destinations: ['0.0.0.0/0'],
            ports:        [80],
            log:          true
          )
        end

        before do
          allow(LifecycleProtocol).to receive(:protocol_for_type).with(lifecycle_type).and_return(lifecycle_protocol)

          SecurityGroup.make(rules: [{ 'protocol' => 'udp', 'ports' => '53', 'destination' => '0.0.0.0/0' }], staging_default: true)
          SecurityGroup.make(rules: [{ 'protocol' => 'tcp', 'ports' => '80', 'destination' => '0.0.0.0/0', 'log' => true }], staging_default: true)
        end

        context 'with a buildpack backend' do
          let(:droplet) { DropletModel.make(:buildpack, package: package, app: app) }
          let(:package) { PackageModel.make(app: app) }

          let(:build_artifacts_cache_download_uri) { 'http://build_artifacts_cache_download_uri.example.com/path/to/bits' }
          let(:lifecycle_type) { 'buildpack' }
          let(:stack) { 'potato-stack' }
          let(:lifecycle_protocol) do
            instance_double(VCAP::CloudController::Diego::Buildpack::LifecycleProtocol,
              lifecycle_data: {
                app_bits_download_uri:              'http://app_bits_download_uri.example.com/path/to/bits',
                build_artifacts_cache_download_uri: build_artifacts_cache_download_uri,
                build_artifacts_cache_upload_uri:   'http://build_artifacts_cache_upload_uri.example.com/path/to/bits',
                buildpacks:                         buildpacks,
                droplet_upload_uri:                 'http://droplet_upload_uri.example.com/path/to/bits',
                stack:                              stack,
              }
            )
          end

          let(:buildpacks) do
            [
              { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url', skip_detect: false },
              { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', skip_detect: true },
            ]
          end

          let(:lifecycle_stack_cached_dependency) do
            ::Diego::Bbs::Models::CachedDependency.new(
              from:      'http://file-server.example.com/v1/static/my_potato_life.tgz',
              to:        '/tmp/lifecycle',
              cache_key: 'buildpack-potato-stack-lifecycle',
            )
          end
          let(:buildpack_one_cached_dependency) do
            ::Diego::Bbs::Models::CachedDependency.new(
              name:      'buildpack-1',
              from:      'buildpack-1-url',
              to:        "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-1-key')}",
              cache_key: 'buildpack-1-key',
            )
          end
          let(:buildpack_two_cached_dependency) do
            ::Diego::Bbs::Models::CachedDependency.new(
              name:      'buildpack-2',
              from:      'buildpack-2-url',
              to:        "/tmp/buildpacks/#{Digest::MD5.hexdigest('buildpack-2-key')}",
              cache_key: 'buildpack-2-key',
            )
          end

          let(:download_app_package_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact: 'app package',
              from:     'http://app_bits_download_uri.example.com/path/to/bits',
              to:       '/tmp/app',
              user:     'vcap'
            )
          end

          let(:download_build_artifacts_cache_action) do
            ::Diego::Bbs::Models::DownloadAction.new(
              artifact: 'build artifacts cache',
              from:     'http://build_artifacts_cache_download_uri.example.com/path/to/bits',
              to:       '/tmp/cache',
              user:     'vcap'
            )
          end

          let(:droplet_upload_url) { CGI.escape('http://droplet_upload_uri.example.com/path/to/bits') }
          let(:upload_droplet_action) do
            ::Diego::Bbs::Models::UploadAction.new(
              artifact: 'droplet',
              from:     '/tmp/droplet',
              to:       "http://cc-uploader.example.com/v1/droplet/#{droplet.guid}?cc-droplet-upload-uri=#{droplet_upload_url}&timeout=90",
              user:     'vcap'
            )
          end

          let(:cache_upload_url) { CGI.escape('http://build_artifacts_cache_upload_uri.example.com/path/to/bits') }
          let(:upload_build_artifacts_cache_action) do
            ::Diego::Bbs::Models::UploadAction.new(
              artifact: 'build artifacts cache',
              from:     '/tmp/output-cache',
              to:       "http://cc-uploader.example.com/v1/build_artifacts/#{droplet.guid}?cc-build-artifacts-upload-uri=#{cache_upload_url}&timeout=90",
              user:     'vcap'
            )
          end

          let(:run_staging_action) do
            ::Diego::Bbs::Models::RunAction.new(
              path:            '/tmp/lifecycle/builder',
              args:            [
                '-buildpackOrder=buildpack-1-key,buildpack-2-key',
                '-skipCertVerify=false',
                '-skipDetect=false'
              ],
              user:            'vcap',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: 30),
              env:             [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'nightshade_fruit', value: 'potato')],
            )
          end

          it 'constructs a TaskDefinition with staging instructions' do
            result = recipe_builder.build_staging_task(config, staging_details)

            expect(result.root_fs).to eq('preloaded:potato-stack')
            expect(result.log_guid).to eq('banana-guid')
            expect(result.metrics_guid).to be_nil
            expect(result.log_source).to eq('STG')
            expect(result.result_file).to eq('/tmp/result.json')
            expect(result.privileged).to be(false)

            expect(result.memory_mb).to eq(42)
            expect(result.disk_mb).to eq(51)
            expect(result.cpu_weight).to eq(50)
            expect(result.legacy_download_user).to eq('vcap')

            annotation = JSON.parse(result.annotation)
            expect(annotation['lifecycle']).to eq(lifecycle_type)
            expect(annotation['completion_callback']).to eq("http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}" \
                                   "/internal/v3/staging/#{droplet.guid}/droplet_completed?start=#{staging_details.start_after_staging}")

            actions = actions_from_task_definition(result)

            parallel_download_action = actions[0].parallel_action
            expect(parallel_download_action.actions[0].download_action).to eq(download_app_package_action)
            expect(parallel_download_action.actions[1].download_action).to eq(download_build_artifacts_cache_action)

            expect(actions[1].run_action).to eq(run_staging_action)

            emit_progress_action = actions[2].emit_progress_action
            expect(emit_progress_action.start_message).to eq('Uploading droplet, build artifacts cache...')
            expect(emit_progress_action.success_message).to eq('Uploading complete')
            expect(emit_progress_action.failure_message_prefix).to eq('Uploading failed')

            parallel_upload_action = actions[2].emit_progress_action.action
            expect(parallel_upload_action.parallel_action).to_not be_nil
            upload_actions = parallel_upload_action.parallel_action.actions
            expect(upload_actions[0].upload_action).to eq(upload_droplet_action)
            expect(upload_actions[1].upload_action).to eq(upload_build_artifacts_cache_action)

            expect(result.egress_rules).to eq([
              rule_dns_everywhere,
              rule_http_everywhere
            ])

            expect(result.cached_dependencies).to eq([
              lifecycle_stack_cached_dependency,
              buildpack_one_cached_dependency, buildpack_two_cached_dependency])
          end

          it 'sets the completion callback to the stager callback url' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.completion_callback_url).to eq("http://stager.example.com/v1/staging/#{droplet.guid}/completed")
          end

          it 'gives the task a TrustedSystemCertificatesPath' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.trusted_system_certificates_path).to eq('/etc/cf-system-certificates')
          end

          it 'determines skip cert verify from config' do
            config[:skip_cert_verify] = true

            result = recipe_builder.build_staging_task(config, staging_details)

            actions    = actions_from_task_definition(result)
            run_action = actions[1].run_action
            expect(run_action.args).to include('-skipCertVerify=true')
          end

          it 'sets the LANG' do
            result = recipe_builder.build_staging_task(config, staging_details)

            env = ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: 'en_US.UTF-8')
            expect(result.environment_variables).to eq([env])
          end

          context 'when no compiler is defined for the requested stack in backend configuration' do
            let(:stack) { 'not-there' }

            it 'returns an error' do
              expect { recipe_builder.build_staging_task(config, staging_details) }.to raise_error(CloudController::Errors::ApiError, /no compiler defined for requested stack/)
            end
          end

          context 'when there is no buildpack artifacts cache' do
            let(:build_artifacts_cache_download_uri) { nil }

            it 'does not include a download action for it' do
              result = recipe_builder.build_staging_task(config, staging_details)

              actions = actions_from_task_definition(result)

              parallel_download_action = actions[0].parallel_action
              expect(parallel_download_action.actions.count).to eq(1)
              expect(parallel_download_action.actions[0].download_action).to eq(download_app_package_action)
            end
          end

          context 'when the compiler for the requested stack is specified as a full URL' do
            let(:stack) { 'valid_url' }
            let(:buildpacks) do
              [{ name: 'custom', key: 'buildpack-1-url', url: 'buildpack-1-url', skip_detect: true }]
            end
            let(:lifecycle_stack_cached_dependency) do
              ::Diego::Bbs::Models::CachedDependency.new(
                from:      'http://example.com',
                to:        '/tmp/lifecycle',
                cache_key: 'buildpack-valid_url-lifecycle',
              )
            end

            it 'uses it in the cached dependency' do
              result = recipe_builder.build_staging_task(config, staging_details)
              expect(result.cached_dependencies).to eq([lifecycle_stack_cached_dependency])
            end

            context 'whe the url is invalid' do
              let(:stack) { 'invalid_url' }

              it 'raises an error for an invalid url' do
                expect { recipe_builder.build_staging_task(config, staging_details) }.to raise_error(CloudController::Errors::ApiError, /invalid compiler URI/)
              end
            end
          end

          context 'with custom buildpack' do
            let(:buildpacks) do
              [{ name: 'custom', key: 'buildpack-1-url', url: 'buildpack-1-url', skip_detect: true }]
            end

            let(:run_staging_action) do
              ::Diego::Bbs::Models::RunAction.new(
                path:            '/tmp/lifecycle/builder',
                args:            [
                  '-buildpackOrder=buildpack-1-url',
                  '-skipCertVerify=false',
                  '-skipDetect=true'
                ],
                user:            'vcap',
                resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: 30),
                env:             [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'nightshade_fruit', value: 'potato')],
              )
            end

            it 'does not download admin buildpacks and skips detect' do
              result = recipe_builder.build_staging_task(config, staging_details)

              actions = actions_from_task_definition(result)
              expect(actions[1].run_action).to eq(run_staging_action)

              expect(result.cached_dependencies).to eq([lifecycle_stack_cached_dependency])
            end
          end

          context 'when the first buildpack does not have skip_detect set' do
            let(:buildpacks) do
              [
                { name: 'buildpack-1', key: 'buildpack-1-key', url: 'buildpack-1-url' },
                { name: 'buildpack-2', key: 'buildpack-2-key', url: 'buildpack-2-url', skip_detect: true },
              ]
            end

            let(:run_staging_action) do
              ::Diego::Bbs::Models::RunAction.new(
                path:            '/tmp/lifecycle/builder',
                args:            [
                  '-buildpackOrder=buildpack-1-key,buildpack-2-key',
                  '-skipCertVerify=false',
                  '-skipDetect=false'
                ],
                user:            'vcap',
                resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: 30),
                env:             [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'nightshade_fruit', value: 'potato')],
              )
            end

            it 'sets skip detect to false' do
              result = recipe_builder.build_staging_task(config, staging_details)

              actions = actions_from_task_definition(result)
              expect(actions[1].run_action).to eq(run_staging_action)
            end
          end

          def actions_from_task_definition(task_definition)
            timeout_action = task_definition.action.timeout_action
            expect(timeout_action).not_to be_nil
            expect(timeout_action.timeout_ms).to eq(90 * 1000)
            serial_action = timeout_action.action.serial_action
            expect(serial_action).not_to be_nil
            expect(serial_action.actions).not_to be_empty
            serial_action.actions
          end
        end

        context 'with a docker backend' do
          let(:droplet) { DropletModel.make(:docker, package: package, app: app) }
          let(:package) { PackageModel.make(:docker, app: app) }

          let(:lifecycle_type) { 'docker' }
          let(:lifecycle_protocol) do
            instance_double(VCAP::CloudController::Diego::Docker::LifecycleProtocol,
              lifecycle_data: {
                docker_image: 'docker/image',
              }
            )
          end

          it 'sets the log guid' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.log_guid).to eq('banana-guid')
          end

          it 'sets the log source' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.log_source).to eq('STG')
          end

          it 'sets the result file' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.result_file).to eq('/tmp/result.json')
          end

          it 'sets privileged container to the config value' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.privileged).to be(false)
          end

          it 'sets the legacy download user' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.legacy_download_user).to eq('vcap')
          end

          it 'sets the annotation' do
            result = recipe_builder.build_staging_task(config, staging_details)

            annotation = JSON.parse(result.annotation)
            expect(annotation['lifecycle']).to eq(lifecycle_type)
            expect(annotation['completion_callback']).to eq("http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}" \
                                   "/internal/v3/staging/#{droplet.guid}/droplet_completed?start=#{staging_details.start_after_staging}")
          end

          it 'sets the cached dependencies' do
            result = recipe_builder.build_staging_task(config, staging_details)

            lifecycle_cached_dependency = ::Diego::Bbs::Models::CachedDependency.new(
              from:      'http://file-server.example.com/v1/static/docker_stack.tgz',
              to:        '/tmp/docker_app_lifecycle',
              cache_key: 'docker-lifecycle',
            )

            expect(result.cached_dependencies).to match_array([lifecycle_cached_dependency])
          end

          it 'sets the memory' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.memory_mb).to eq(42)
          end

          it 'sets the disk' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.disk_mb).to eq(51)
          end

          it 'sets the egress rules' do
            result = recipe_builder.build_staging_task(config, staging_details)

            expect(result.egress_rules).to eq([
              rule_dns_everywhere,
              rule_http_everywhere
            ])
          end

          it 'sets the rootfs' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.root_fs).to eq('preloaded:docker-stack')
          end

          it 'sets the completion callback' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.completion_callback_url).to eq("http://stager.example.com/v1/staging/#{droplet.guid}/completed")
          end

          it 'sets the trusted cert path' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.trusted_system_certificates_path).to eq('/etc/cf-system-certificates')
          end

          it 'sets the timeout' do
            result = recipe_builder.build_staging_task(config, staging_details)
            expect(result.trusted_system_certificates_path).to eq('/etc/cf-system-certificates')
          end

          it 'sets the run action' do
            result = recipe_builder.build_staging_task(config, staging_details)

            run_action = ::Diego::Bbs::Models::RunAction.new(
              path:            '/tmp/docker_app_lifecycle/builder',
              args:            [
                '-outputMetadataJSONFilename=/tmp/result.json',
                '-dockerRef=docker/image',
                '-insecureDockerRegistries=registry-1,registry-2'
              ],
              user:            'vcap',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: 30),
              env:             [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'nightshade_fruit', value: 'potato')],
            )

            timeout_action = result.action.timeout_action
            expect(timeout_action).not_to be_nil
            expect(timeout_action.timeout_ms).to eq(90 * 1000)

            emit_progress_action = timeout_action.action.emit_progress_action
            expect(emit_progress_action.start_message).to eq('Staging...')
            expect(emit_progress_action.success_message).to eq('Staging Complete')
            expect(emit_progress_action.failure_message_prefix).to eq('Staging Failed')

            expect(emit_progress_action.action.run_action).to eq(run_action)
          end
        end
      end
    end
  end
end
