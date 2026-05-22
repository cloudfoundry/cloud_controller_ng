require 'spec_helper'
require 'presenters/v3/app_manifest_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppManifestPresenter do
    let(:environment_variables) { { 'one' => 'potato', 'two' => 'tomato' } }
    let(:app) do
      create(:app_model, environment_variables:)
    end
    let(:space) { app.space }

    describe '#to_hash' do
      context 'when the app has no associated resources' do
        let(:service_bindings) { [] }
        let(:route_mappings) { [] }

        context 'for buildpack apps' do
          it 'returns the application name and stack' do
            result = AppManifestPresenter.new(app, service_bindings, route_mappings).to_hash
            application = result[:applications].first
            application.except!(:env, :features)
            expect(application).to eq({ lifecycle: 'buildpack', name: app.name, stack: app.lifecycle_data.stack })
          end
        end

        context 'for docker apps' do
          let(:app) do
            create(:app_model, :docker,
                   environment_variables:)
          end

          it 'returns the application name' do
            result = AppManifestPresenter.new(app, service_bindings, route_mappings).to_hash
            application = result[:applications].first
            application.except!(:env, :features)
            expect(application).to eq({ lifecycle: 'docker', name: app.name })
          end
        end

        it 'returns the environment variables' do
          result = AppManifestPresenter.new(app, service_bindings, route_mappings).to_hash
          application = result[:applications].first
          expect(application[:env]).to eq(environment_variables)
        end

        it 'returns the app features' do
          result = AppManifestPresenter.new(app, service_bindings, route_mappings).to_hash
          application = result[:applications].first
          expect(application[:features].keys).to contain_exactly(:ssh, :revisions, :'service-binding-k8s', :'file-based-vcap-services')
        end

        context 'when environment variables is an empty hash' do
          let(:environment_variables) { {} }

          it 'does not include the environment variables key' do
            result = AppManifestPresenter.new(app, service_bindings, route_mappings).to_hash
            application = result[:applications].first
            expect(application[:env]).to be_nil
          end
        end
      end

      context 'when the app has other associated resources' do
        let(:service_instance) do
          create(:managed_service_instance, space: space,
                                            name: 'service-instance-a')
        end
        let(:service_instance2) do
          create(:managed_service_instance, space: space,
                                            name: 'service-instance-z')
        end
        let(:service_binding) { create(:service_binding, app:, service_instance:) }
        let(:service_binding2) { create(:service_binding, app: app, service_instance: service_instance2) }
        let(:service_bindings) { [service_binding2, service_binding] }

        let(:route) { create(:route, host: 'aaa') }
        let(:route2) { create(:route, host: 'zzz') }
        let!(:route_mapping1) { create(:route_mapping_model, app:, route:) }
        let!(:route_mapping2) { create(:route_mapping_model, app: app, route: route2) }

        let!(:process1) do
          VCAP::CloudController::ProcessModelFactory.make(
            app: app,
            health_check_type: 'http',
            health_check_http_endpoint: '/foobar',
            health_check_timeout: 5,
            log_rate_limit: 1_048_576,
            command: 'Do it now!',
            type: 'aaaaa'
          )
        end
        let!(:process2) do
          create(:process_model, app: app,
                                 type: 'zzzzz')
        end

        let!(:app_label) { create(:app_label_model, resource_guid: app.guid, key_name: 'potato', value: 'idaho') }
        let!(:app_annotation) { create(:app_annotation_model, resource_guid: app.guid, key_name: 'style', value: 'mashed') }

        let!(:sidecar1) { create(:sidecar_model, name: 'authenticator', command: './authenticator', app: app) }
        let!(:sidecar2) { create(:sidecar_model, name: 'my_sidecar', command: 'rackup', app: app) }

        let!(:sidecar_process_type1) { create(:sidecar_process_type_model, type: 'worker', sidecar: sidecar1, app_guid: app.guid) }
        let!(:sidecar_process_type2) { create(:sidecar_process_type_model, type: 'web', sidecar: sidecar1, app_guid: app.guid) }
        let!(:sidecar_process_type3) { create(:sidecar_process_type_model, type: 'other_worker', sidecar: sidecar2, app_guid: app.guid) }

        it 'presents the app manifest' do
          result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash

          application = result[:applications].first
          expect(application[:name]).to eq(app.name)
          expect(application[:services]).to eq([
            service_instance.name,
            service_instance2.name
          ])
          expect(application[:routes]).to eq([
            { route: route.uri, protocol: 'http1', options: {} },
            { route: route2.uri, protocol: 'http1', options: {} }
          ])
          expect(application[:env]).to match({ 'one' => 'potato', 'two' => 'tomato' })
          expect(application[:metadata]).to match({ labels: { 'potato' => 'idaho' }, annotations: { 'style' => 'mashed' } })
          expect(application[:processes]).to eq([
            {
              'type' => process1.type,
              'instances' => process1.instances,
              'memory' => "#{process1.memory}M",
              'log-rate-limit-per-second' => '1M',
              'disk_quota' => "#{process1.disk_quota}M",
              'command' => process1.command,
              'health-check-type' => process1.health_check_type,
              'health-check-http-endpoint' => process1.health_check_http_endpoint,
              'readiness-health-check-type' => process1.readiness_health_check_type,
              'timeout' => process1.health_check_timeout
            },
            {
              'type' => process2.type,
              'instances' => process2.instances,
              'log-rate-limit-per-second' => '1M',
              'memory' => "#{process2.memory}M",
              'disk_quota' => "#{process2.disk_quota}M",
              'health-check-type' => process2.health_check_type,
              'readiness-health-check-type' => process2.readiness_health_check_type
            }
          ])
          expect(application[:sidecars]).to eq(
            [
              {
                'name' => 'authenticator',
                'process_types' => %w[web worker],
                'command' => './authenticator'
              },
              {
                'name' => 'my_sidecar',
                'process_types' => ['other_worker'],
                'command' => 'rackup'
              }
            ]
          )
        end

        context 'when a process is missing attributes' do
          let!(:process1) do
            create(:process_model, app: app,
                                   health_check_timeout: nil,
                                   health_check_http_endpoint: nil)
          end

          it 'does not include the missing attributes in the hash' do
            result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash
            application = result[:applications].first

            expect(application[:processes]).to eq([
              {
                'type' => process1.type,
                'instances' => process1.instances,
                'log-rate-limit-per-second' => '1M',
                'memory' => "#{process1.memory}M",
                'disk_quota' => "#{process1.disk_quota}M",
                'health-check-type' => process1.health_check_type,
                'readiness-health-check-type' => process1.readiness_health_check_type
              },
              {
                'type' => process2.type,
                'instances' => process2.instances,
                'log-rate-limit-per-second' => '1M',
                'memory' => "#{process2.memory}M",
                'disk_quota' => "#{process2.disk_quota}M",
                'health-check-type' => process2.health_check_type,
                'readiness-health-check-type' => process2.readiness_health_check_type
              }
            ])
          end
        end

        context 'when the app is a buildpack app' do
          before do
            create(:buildpack, name: 'limabean')
            app.lifecycle_data.update(
              buildpacks: ['limabean', 'git://user:pass@github.com/repo'],
              stack: 'the-happiest-stack'
            )
          end

          it 'presents the buildpacks in the order originally specified (not alphabetical)' do
            result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash
            application = result[:applications].first
            expect(application[:stack]).to eq(app.lifecycle_data.stack)
            expect(application[:buildpacks]).to eq(['limabean', 'git://user:pass@github.com/repo'])
          end
        end

        context 'when the app is a docker app' do
          let(:app) { create(:app_model, :docker) }

          context 'when the app has a current droplet' do
            let(:docker_username) { 'xXxMyL1ttlePwnyxXx' }
            let!(:process1) do
              VCAP::CloudController::ProcessModelFactory.make(
                app: app,
                health_check_type: 'http',
                health_check_http_endpoint: '/foobar',
                health_check_timeout: 5,
                command: 'Do it now!',
                docker_image: 'my-image:my-tag',
                docker_credentials: {
                  'username' => docker_username
                }
              )
            end

            it 'presents the docker image and username' do
              result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash
              application = result[:applications].first

              expect(application[:buildpacks]).to be_nil
              expect(application[:stack]).to be_nil
              expect(application[:docker]).to eq({
                                                   image: 'my-image:my-tag',
                                                   username: 'xXxMyL1ttlePwnyxXx'
                                                 })
            end

            context 'when there is no docker username' do
              let(:docker_username) { nil }

              it 'does not return a username' do
                result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash
                application = result[:applications].first

                expect(application[:buildpacks]).to be_nil
                expect(application[:stack]).to be_nil
                expect(application[:docker]).to eq({
                                                     image: 'my-image:my-tag'
                                                   })
              end
            end
          end

          context 'when the app has no current droplet' do
            let!(:process1) do
              nil
            end

            let!(:package) do
              create(:package_model, :docker,
                     docker_image: 'my-image:tag',
                     docker_username: 'xXxMyL1ttlePwnyxXx',
                     app: app)
            end

            it 'omits all docker information, even if the app has packages' do
              expect(app.packages).to have(1).items
              result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash
              application = result[:applications].first

              expect(application[:docker]).to be_nil
            end
          end
        end

        context 'metadata' do
          context 'when there is no metadata' do
            before do
              app_label.destroy
              app_annotation.destroy
            end

            it 'does not present the metadata hash' do
              result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash

              application = result[:applications].first
              expect(application[:metadata]).to be_nil
            end
          end

          context 'when there are labels but no annotations' do
            before do
              app_annotation.destroy
            end

            it 'presents labels and does not present the annotations hash' do
              result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash

              application = result[:applications].first
              expect(application[:metadata]).to match({ labels: { 'potato' => 'idaho' } })
            end
          end

          context 'when there are annotations but no labels' do
            before do
              app_label.destroy
            end

            it 'presents annotations and does not present the labels hash' do
              result = AppManifestPresenter.new(app, service_bindings, app.route_mappings).to_hash

              application = result[:applications].first
              expect(application[:metadata]).to match({ annotations: { 'style' => 'mashed' } })
            end
          end
        end
      end
    end
  end
end
