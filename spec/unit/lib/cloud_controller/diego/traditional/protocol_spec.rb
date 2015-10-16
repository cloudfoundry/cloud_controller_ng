require 'spec_helper'

module VCAP::CloudController
  module Diego
    module Traditional
      describe Protocol do
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
        let(:app) do
          AppFactory.make(
            health_check_timeout: default_health_check_timeout,
            command: 'start_me',
            diego: true
          )
        end

        subject(:protocol) do
          Protocol.new(blobstore_url_generator, egress_rules)
        end

        before do
          allow(egress_rules).to receive(:staging).and_return(['staging_egress_rule'])
          allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])
        end

        describe '#stage_app_request' do
          let(:request) { protocol.stage_app_request(app, config) }

          it 'returns the staging request message to be used by the stager client' do
            expect(request).to eq(protocol.stage_app_message(app, config).to_json)
          end
        end

        describe '#stage_app_message' do
          let(:staging_env) { { 'KEY' => 'staging_value' } }

          before do
            override = {
              external_port:             external_port,
              internal_service_hostname: internal_service_hostname,
              internal_api:              {
                auth_user:     user,
                auth_password: password
              },
              staging:                   {
                minimum_staging_memory_mb:             128,
                minimum_staging_disk_mb:               128,
                minimum_staging_file_descriptor_limit: 128,
                timeout_in_seconds:                    90,
                auth:                                  { user: 'user', password: 'password' },
              }
            }
            TestConfig.override(override)

            group = EnvironmentVariableGroup.staging
            group.environment_json = staging_env
            group.save
          end

          let(:internal_service_hostname) { 'internal.awesome.sauce' }
          let(:external_port) { '7777' }
          let(:staging_guid) { StagingGuid.from_app(app) }
          let(:user) { 'user' }
          let(:password) { 'password' }

          let(:message) { protocol.stage_app_message(app, config) }
          let(:app) { AppFactory.make(staging_task_id: 'fake-staging-task-id', diego: true) }
          let(:buildpack_generator) { BuildpackEntryGenerator.new(blobstore_url_generator) }

          it 'contains the correct payload for staging a traditional app' do
            expect(message).to eq({
                  app_id:              app.guid,
                  log_guid:            app.guid,
                  memory_mb:           app.memory,
                  disk_mb:             app.disk_quota,
                  file_descriptors:    app.file_descriptors,
                  environment:         Environment.new(app, staging_env).as_json,
                  egress_rules:        ['staging_egress_rule'],
                  timeout:             90,
                  lifecycle:           'buildpack',
                  lifecycle_data:      {
                    build_artifacts_cache_download_uri: 'http://buildpack-artifacts-cache.com',
                    build_artifacts_cache_upload_uri:   'http://buildpack-artifacts-cache.up.com',
                    app_bits_download_uri:              'http://app-package.com',
                    droplet_upload_uri:                 'http://droplet-upload-uri',
                    buildpacks:                         buildpack_generator.buildpack_entries(app),
                    stack:                              app.stack.name,
                  },
                  completion_callback: "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/staging/#{staging_guid}/completed"
                })
          end

          describe 'buildpack payload' do
            let(:buildpack_url) { 'http://example.com/buildpack' }
            before do
              Buildpack.create(name: 'ruby', key: 'ruby-buildpack-key', position: 2)

              allow(blobstore_url_generator).to receive(:admin_buildpack_download_url).and_return(buildpack_url)
            end

            context 'when auto-detecting' do
              it 'sends buildpacks without skip_detect' do
                expect(message[:lifecycle_data][:buildpacks]).to have(1).items
                buildpack = message[:lifecycle_data][:buildpacks][0]
                expect(buildpack).to include(name: 'ruby')
                expect(buildpack).to_not include(:skip_detect)
              end
            end

            context 'when a buildpack is requested' do
              before do
                app.buildpack = 'ruby'
              end

              it 'sends buildpacks with skip detect' do
                expect(message[:lifecycle_data][:buildpacks]).to have(1).items
                buildpack = message[:lifecycle_data][:buildpacks][0]
                expect(buildpack).to include(name: 'ruby', skip_detect: true)
              end
            end

            context 'when a custom buildpack is requested' do
              let(:buildpack_url) { 'http://example.com/buildpack' }
              before do
                app.buildpack = buildpack_url
              end

              it 'sends buildpacks with skip detect' do
                expect(message[:lifecycle_data][:buildpacks]).to have(1).items
                buildpack = message[:lifecycle_data][:buildpacks][0]
                expect(buildpack).to include(url: buildpack_url, skip_detect: true)
              end
            end
          end

          context 'when the app memory is less than the minimum staging memory' do
            let(:app) { AppFactory.make(memory: 127, diego: true) }

            subject(:message) do
              protocol.stage_app_message(app, config)
            end

            it 'uses the minimum staging memory' do
              expect(message[:memory_mb]).to eq(config[:staging][:minimum_staging_memory_mb])
            end
          end

          context 'when the app disk is less than the minimum staging disk' do
            let(:app) { AppFactory.make(disk_quota: 127, diego: true) }

            subject(:message) do
              protocol.stage_app_message(app, config)
            end

            it 'includes the fields needed to stage a Docker app' do
              expect(message[:disk_mb]).to eq(config[:staging][:minimum_staging_disk_mb])
            end
          end

          context 'when the app fd limit is less than the minimum staging fd limit' do
            let(:app) { AppFactory.make(file_descriptors: 127, diego: true) }

            subject(:message) do
              protocol.stage_app_message(app, config)
            end

            it 'includes the fields needed to stage a Docker app' do
              expect(message[:file_descriptors]).to eq(config[:staging][:minimum_staging_file_descriptor_limit])
            end
          end
        end

        describe '#desire_app_request' do
          let(:request) { protocol.desire_app_request(app, default_health_check_timeout) }

          it 'returns the message' do
            expect(request).to match_json(protocol.desire_app_message(app, default_health_check_timeout))
          end
        end

        describe '#desire_app_message' do
          let(:message) { protocol.desire_app_message(app, default_health_check_timeout) }

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
          end

          it 'is a messsage with the information nsync needs to desire the app' do
            expect(message).to eq({
                  'disk_mb' => app.disk_quota,
                  'droplet_uri' => 'fake-droplet_uri',
                  'environment' => Environment.new(app, running_env).as_json,
                  'file_descriptors' => app.file_descriptors,
                  'health_check_type' => app.health_check_type,
                  'health_check_timeout_in_seconds' => app.health_check_timeout,
                  'log_guid' => app.guid,
                  'memory_mb' => app.memory,
                  'num_instances' => app.desired_instances,
                  'process_guid' => ProcessGuid.from_app(app),
                  'stack' => app.stack.name,
                  'start_command' => app.command,
                  'execution_metadata' => app.execution_metadata,
                  'routes' => [
                    route_without_service.uri,
                    route_with_service.uri
                  ],
                  'routing_info' => {
                    'http_routes' => [
                      { 'hostname' => route_without_service.uri },
                      { 'hostname' => route_with_service.uri,
                        'route_service_url' => route_with_service.route_binding.route_service_url
                      }
                    ]
                  },
                  'egress_rules' => ['running_egress_rule'],
                  'etag' => app.updated_at.to_f.to_s,
                  'allow_ssh' => true,
                })
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

          describe 'start_command' do
            context 'when app has a command set' do
              before do
                app.command = 'command from app'
                app.save
              end
              it 'uses it' do
                expect(message['start_command']).to eq('command from app')
              end
            end

            context 'when app does not have a start command set' do
              before do
                app.command = ''
                app.save
                app.current_droplet.detected_start_command = 'command from droplet'
                app.current_droplet.save
              end
              it 'uses the droplet detected start command' do
                expect(message['start_command']).to eq('command from droplet')
              end
            end
          end
        end
      end
    end
  end
end
