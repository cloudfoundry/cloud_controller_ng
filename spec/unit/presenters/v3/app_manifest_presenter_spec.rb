require 'spec_helper'
require 'presenters/v3/app_manifest_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppManifestPresenter do
    let(:environment_variables) { { 'one' => 'potato', 'two' => 'tomato' } }
    let(:app) { FactoryBot.create(:app, :buildpack, environment_variables: environment_variables) }
    let(:space) { app.space }

    describe '#to_hash' do
      context 'when the app has no associated resources' do
        let(:service_bindings) { [] }
        let(:routes) { [] }
        let(:environment_variables) { nil }

        context 'for buildpack apps' do
          it 'only returns the application name and stack' do
            result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
            application = result[:applications].first
            expect(application).to eq({ name: app.name, stack: app.lifecycle_data.stack })
          end
        end

        context 'for docker apps' do
          let(:app) { FactoryBot.create(:app, :docker, environment_variables: environment_variables) }

          it 'only returns application name' do
            result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
            application = result[:applications].first
            expect(application).to eq({ name: app.name })
          end
        end

        context 'when environment variables is an empty hash' do
          let(:environment_variables) { {} }

          it 'does not include the environment variables key' do
            result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
            application = result[:applications].first
            expect(application[:env]).to be_nil
          end
        end
      end

      context 'when the app has other associated resources' do
        let(:service_instance) do
          VCAP::CloudController::ManagedServiceInstance.make(
            space: space,
            name: 'service-instance-a'
          )
        end
        let(:service_instance2) do
          VCAP::CloudController::ManagedServiceInstance.make(
            space: space,
            name: 'service-instance-z'
          )
        end
        let(:service_binding) { VCAP::CloudController::ServiceBinding.make(app: app, service_instance: service_instance) }
        let(:service_binding2) { VCAP::CloudController::ServiceBinding.make(app: app, service_instance: service_instance2) }
        let(:service_bindings) { [service_binding2, service_binding] }

        let(:route) { VCAP::CloudController::Route.make host: 'aaa' }
        let(:route2) { VCAP::CloudController::Route.make host: 'zzz' }

        let(:routes) { [route2, route] }

        let!(:process1) do
          VCAP::CloudController::ProcessModelFactory.make(
            app: app,
            health_check_type: 'http',
            health_check_http_endpoint: '/foobar',
            health_check_timeout: 5,
            command: 'Do it now!',
            type: 'aaaaa',
          )
        end
        let!(:process2) do
          VCAP::CloudController::ProcessModel.make(
            app: app,
            type: 'zzzzz',
          )
        end

        it 'presents the deployment as json, with routes, service instances, and processes in alphabetical order' do
          result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
          application = result[:applications].first
          expect(application[:name]).to eq(app.name)
          expect(application[:services]).to eq([
            service_instance.name,
            service_instance2.name
          ])
          expect(application[:routes]).to eq([
            { route: route.uri },
            { route: route2.uri }
          ])
          expect(application[:env]).to match({ 'one' => 'potato', 'two' => 'tomato' })
          expect(application[:processes]).to eq([
            {
              'type' => process1.type,
              'instances' => process1.instances,
              'memory' => "#{process1.memory}M",
              'disk_quota' => "#{process1.disk_quota}M",
              'command' => process1.command,
              'health-check-type' => process1.health_check_type,
              'health-check-http-endpoint' => process1.health_check_http_endpoint,
              'timeout' => process1.health_check_timeout,
            },
            {
              'type' => process2.type,
              'instances' => process2.instances,
              'memory' => "#{process2.memory}M",
              'disk_quota' => "#{process2.disk_quota}M",
              'health-check-type' => process2.health_check_type,
            }
          ])
        end

        context 'when a process is missing attributes' do
          let!(:process1) do
            VCAP::CloudController::ProcessModel.make(
              app: app,
              health_check_timeout: nil,
              health_check_http_endpoint: nil,
            )
          end

          it 'does not include the missing attributes in the hash' do
            result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
            application = result[:applications].first

            expect(application[:processes]).to eq([
              {
                'type' => process1.type,
                'instances' => process1.instances,
                'memory' => "#{process1.memory}M",
                'disk_quota' => "#{process1.disk_quota}M",
                'health-check-type' => process1.health_check_type,
              },
              {
                'type' => process2.type,
                'instances' => process2.instances,
                'memory' => "#{process2.memory}M",
                'disk_quota' => "#{process2.disk_quota}M",
                'health-check-type' => process2.health_check_type,
              }
            ])
          end
        end

        context 'when the app is a buildpack app' do
          before do
            VCAP::CloudController::Buildpack.make(name: 'limabean')
            app.lifecycle_data.update(
              buildpacks: ['limabean', 'git://user:pass@github.com/repo'],
              stack: 'the-happiest-stack',
            )
          end

          it 'presents the buildpacks in the order originally specified (not alphabetical)' do
            result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
            application = result[:applications].first
            expect(application[:stack]).to eq(app.lifecycle_data.stack)
            expect(application[:buildpacks]).to eq(['limabean', 'git://user:pass@github.com/repo'])
          end
        end

        context 'when the app is a docker app' do
          let(:app) { FactoryBot.create(:app, :docker) }

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
              result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
              application = result[:applications].first

              expect(application[:buildpacks]).to be_nil
              expect(application[:stack]).to be_nil
              expect(application[:docker]).to eq({
                'image': 'my-image:my-tag',
                'username': 'xXxMyL1ttlePwnyxXx'
              })
            end

            context 'when there is no docker username' do
              let(:docker_username) { nil }

              it 'does not return a username' do
                result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
                application = result[:applications].first

                expect(application[:buildpacks]).to be_nil
                expect(application[:stack]).to be_nil
                expect(application[:docker]).to eq({
                  'image': 'my-image:my-tag',
                })
              end
            end
          end

          context 'when the app has no current droplet' do
            let!(:process1) do
              nil
            end

            let!(:package) do
              VCAP::CloudController::PackageModel.make(
                :docker,
                docker_image: 'my-image:tag',
                docker_username: 'xXxMyL1ttlePwnyxXx',
                app: app
              )
            end

            it 'omits all docker information, even if the app has packages' do
              expect(app.packages).to have(1).items
              result = AppManifestPresenter.new(app, service_bindings, routes).to_hash
              application = result[:applications].first

              expect(application[:docker]).to be_nil
            end
          end
        end
      end
    end
  end
end
