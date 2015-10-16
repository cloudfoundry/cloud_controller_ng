require 'spec_helper'
require 'cloud_controller/diego/docker/protocol'

module VCAP::CloudController
  module Diego
    module Docker
      describe Protocol do
        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
        end

        let(:default_health_check_timeout) { 9999 }
        let(:config) { TestConfig.config }
        let(:egress_rules) { double(:egress_rules) }

        let(:app) do
          AppFactory.make(
            docker_image: 'fake/docker_image',
            health_check_timeout: 120,
            enable_ssh: true,
            diego: true
          )
        end

        subject(:protocol) do
          Protocol.new(egress_rules)
        end

        before do
          allow(egress_rules).to receive(:staging).and_return(['staging_egress_rule'])
          allow(egress_rules).to receive(:running).with(app).and_return(['running_egress_rule'])
        end

        describe '#stage_app_request' do
          subject(:request) do
            protocol.stage_app_request(app, config)
          end

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

          let(:staging_guid) { StagingGuid.from_app(app) }
          let(:external_port) { 8989 }
          let(:internal_service_hostname) { 'awesome.com' }
          let(:user) { 'user' }
          let(:password) { 'password' }
          let(:message) { protocol.stage_app_message(app, config) }

          it 'contains the correct payload for staging a Docker app' do
            expect(message).to eq({
                  app_id:              app.guid,
                  log_guid:            app.guid,
                  environment:         Environment.new(app, staging_env).as_json,
                  memory_mb:           app.memory,
                  disk_mb:             app.disk_quota,
                  file_descriptors:    app.file_descriptors,
                  egress_rules:        ['staging_egress_rule'],
                  timeout:             90,
                  lifecycle:           'docker',
                  lifecycle_data:      {
                    docker_image: app.docker_image,
                  },
                  completion_callback: "http://#{user}:#{password}@#{internal_service_hostname}:#{external_port}/internal/staging/#{staging_guid}/completed"
                })
          end

          context 'when the app memory is less than the minimum staging memory' do
            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', memory: 127, diego: true) }

            subject(:message) do
              protocol.stage_app_message(app, config)
            end

            it 'uses the minimum staging memory' do
              expect(message[:memory_mb]).to eq(config[:staging][:minimum_staging_memory_mb])
            end
          end

          context 'when the app disk is less than the minimum staging disk' do
            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', disk_quota: 127, diego: true) }

            subject(:message) do
              protocol.stage_app_message(app, config)
            end

            it 'includes the fields needed to stage a Docker app' do
              expect(message[:disk_mb]).to eq(config[:staging][:minimum_staging_disk_mb])
            end
          end

          context 'when the app fd limit is less than the minimum staging fd limit' do
            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', file_descriptors: 127, diego: true) }

            subject(:message) do
              protocol.stage_app_message(app, config)
            end

            it 'includes the fields needed to stage a Docker app' do
              expect(message[:file_descriptors]).to eq(config[:staging][:minimum_staging_file_descriptor_limit])
            end
          end

          context 'when there are image credentials' do
            let(:server) { 'http://loginServer.com' }
            let(:user) { 'user' }
            let(:password) { 'password' }
            let(:email) { 'email' }
            let(:docker_credentials) do
              {
                docker_login_server: server,
                docker_user: user,
                docker_password: password,
                docker_email: email
              }
            end
            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', docker_credentials_json: docker_credentials, diego: true) }

            it 'uses the provided credentials to stage a Docker app' do
              expect(message[:lifecycle_data][:docker_login_server]).to eq(server)
              expect(message[:lifecycle_data][:docker_user]).to eq(user)
              expect(message[:lifecycle_data][:docker_password]).to eq(password)
              expect(message[:lifecycle_data][:docker_email]).to eq(email)
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

            route_with_service.save
            route_without_service.save
            app.add_route(route_without_service)
            app.add_route(route_with_service)
          end

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
              'environment' => Environment.new(app, running_env).as_json,
              'num_instances' => app.desired_instances,
              'routes' => [
                route_without_service.uri,
                route_with_service.uri
              ],
              'routing_info' => {
                'http_routes' => [
                  { 'hostname' => route_without_service.uri },
                  { 'hostname' => route_with_service.uri, 'route_service_url' => route_with_service.route_binding.route_service_url }
                ]
              },
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

            let(:app) { AppFactory.make(docker_image: 'fake/docker_image', health_check_timeout: nil, diego: true) }

            it 'uses the default app health check from the config' do
              expect(message['health_check_timeout_in_seconds']).to eq(default_health_check_timeout)
            end
          end

          context 'when there is a cached_docker_image' do
            let(:cached_docker_image) { '10.244.2.6:8080/uuid' }
            let(:app) { AppFactory.make(docker_image: 'cloudfoundry/diego-docker-app:latest', diego: true) }

            before { app.current_droplet.cached_docker_image = cached_docker_image }

            it 'uses the cached_docker_image instead of the user provided' do
              expect(message['docker_image']).to eq(cached_docker_image)
            end
          end

          context 'when there is no current_droplet for app' do
            let(:docker_image) { 'cloudfoundry/diego-docker-app:latest' }
            let(:app) do
              App.make(
                name: Sham.name,
                space: Space.make,
                stack: Stack.default,
                docker_image: docker_image,
                diego: true
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
