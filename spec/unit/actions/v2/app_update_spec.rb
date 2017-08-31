require 'spec_helper'
require 'actions/v2/app_update'

module VCAP::CloudController
  RSpec.describe V2::AppUpdate do
    let(:access_validator) { double('access_validator', validate_access: true) }
    let(:stagers) { instance_double(Stagers) }
    subject(:app_update) { described_class.new(access_validator: access_validator, stagers: stagers) }

    describe 'update' do
      it 'updates the process' do
        process = ProcessModel.make
        app     = process.app

        request_attrs = {
          'production'                 => false,
          'memory'                     => 4,
          'instances'                  => 2,
          'disk_quota'                 => 30,
          'command'                    => 'new-command',
          'health_check_type'          => 'http',
          'health_check_timeout'       => 20,
          'health_check_http_endpoint' => '/health',
          'diego'                      => true,
          'enable_ssh'                 => false,
          'ports'                      => [8080],
          'route_guids'                => [],
        }

        app_update.update(app, process, request_attrs)

        expect(process.production).to eq(false)
        expect(process.memory).to eq(4)
        expect(process.instances).to eq(2)
        expect(process.disk_quota).to eq(30)
        expect(process.command).to eq('new-command')
        expect(process.health_check_type).to eq('http')
        expect(process.health_check_timeout).to eq(20)
        expect(process.health_check_http_endpoint).to eq('/health')
        expect(process.diego).to eq(true)
        expect(process.ports).to eq([8080])
        expect(process.route_guids).to eq([])
      end

      it 'updates the app' do
        process = ProcessModel.make
        app     = process.app
        stack   = Stack.make(name: 'stack-name')

        request_attrs = {
          'name'             => 'maria',
          'environment_json' => { 'KEY' => 'val' },
          'stack_guid'       => stack.guid,
          'buildpack'        => 'http://example.com/buildpack',
          'enable_ssh' => false
        }

        app_update.update(app, process, request_attrs)

        expect(process.name).to eq('maria')
        expect(process.environment_json).to eq({ 'KEY' => 'val' })
        expect(process.stack).to eq(stack)
        expect(process.custom_buildpack_url).to eq('http://example.com/buildpack')

        expect(app.name).to eq('maria')
        expect(app.environment_variables).to eq({ 'KEY' => 'val' })
        expect(app.enable_ssh).to be false
        expect(app.lifecycle_type).to eq(BuildpackLifecycleDataModel::LIFECYCLE_TYPE)
        expect(app.lifecycle_data.stack).to eq('stack-name')
        expect(app.lifecycle_data.buildpacks).to eq(['http://example.com/buildpack'])
      end

      context 'updating buildpack' do
        context 'when custom buildpacks are disabled' do
          let(:process) { ProcessModel.make }
          let(:app) { process.app }

          before { TestConfig.override(disable_custom_buildpacks: true) }

          it 'does NOT allow a public git url' do
            request_attrs = { 'buildpack' => 'http://example.com/buildpack' }

            expect {
              app_update.update(app, process, request_attrs)
            }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
          end

          it 'does NOT allow a public http url' do
            request_attrs = { 'buildpack' => 'http://example.com/foo' }

            expect {
              app_update.update(app, process, request_attrs)
            }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
          end

          it 'does allow a buildpack name' do
            admin_buildpack = Buildpack.make
            request_attrs   = { 'buildpack' => admin_buildpack.name }

            expect {
              app_update.update(app, process, request_attrs)
            }.not_to raise_error
          end

          it 'does not allow a private git url' do
            request_attrs = { 'buildpack' => 'git://github.com/johndoe/my-buildpack.git' }

            expect {
              app_update.update(app, process, request_attrs)
            }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
          end

          it 'does not allow a private git url with ssh schema' do
            request_attrs = { 'buildpack' => 'ssh://git@example.com/foo.git' }

            expect {
              app_update.update(app, process, request_attrs)
            }.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
          end
        end

        describe 'empty values (that trigger autodetect)' do
          it 'allows buildpack to be set to nil' do
            process = ProcessModel.make
            app     = process.app

            request_attrs = {
              'buildpack' => nil,
            }

            app_update.update(app, process, request_attrs)

            expect(process.app.lifecycle_data.buildpacks).to eq([])
          end

          it 'allows buildpack to be set to empty string' do
            process = ProcessModel.make
            app     = process.app

            request_attrs = {
              'buildpack' => '',
            }

            app_update.update(app, process, request_attrs)

            expect(process.app.lifecycle_data.buildpacks).to eq([])
          end
        end
      end

      describe 'setting stack' do
        let(:new_stack) { Stack.make }
        let(:process) { ProcessModel.make }
        let(:app) { process.app }
        let(:request_attrs) { { 'stack_guid' => new_stack.guid } }

        it 'changes the stack' do
          expect(process.stack).not_to eq(new_stack)
          app_update.update(app, process, request_attrs)

          expect(process.reload.stack).to eq(new_stack)
        end

        context 'when the app is already staged' do
          let(:process) do
            ProcessModelFactory.make(
              instances: 1,
              state:     'STARTED'
            )
          end

          it 'marks the app for re-staging' do
            expect(process.needs_staging?).to eq(false)

            app_update.update(app, process, request_attrs)

            expect(process.needs_staging?).to eq(true)
            expect(process.staged?).to eq(false)
          end
        end

        context 'when the app needs staged' do
          let(:process) { ProcessModelFactory.make(state: 'STARTED') }

          before do
            PackageModel.make(app: app, package_hash: 'some-hash', state: PackageModel::READY_STATE)
            process.reload
          end

          it 'keeps app as needs staging' do
            expect(process.staged?).to be false
            expect(process.needs_staging?).to be true

            app_update.update(app, process, request_attrs)

            process.reload
            expect(process.staged?).to be false
            expect(process.needs_staging?).to be true
          end
        end

        context 'when the app was never staged' do
          let(:process) { ProcessModel.make }

          it 'does not mark the app for staging' do
            expect(process.staged?).to be_falsey
            expect(process.needs_staging?).to be_nil

            app_update.update(app, process, request_attrs)
            process.reload

            expect(process.staged?).to be_falsey
            expect(process.needs_staging?).to be_nil
          end
        end
      end

      describe 'changing lifecycle types' do
        context 'when changing from docker to buildpack' do
          let(:process) { ProcessModel.make(app: AppModel.make(:docker)) }
          let(:app) { process.app }

          it 'raises an error setting buildpack' do
            request_attrs = { 'buildpack' => 'https://buildpack.example.com' }

            expect {
              app_update.update(app, process, request_attrs)
            }.to raise_error(/Lifecycle type cannot be changed/)
          end

          it 'raises an error setting stack' do
            request_attrs = { 'stack_guid' => 'phat-stackz' }

            expect {
              app_update.update(app, process, request_attrs)
            }.to raise_error(/Lifecycle type cannot be changed/)
          end
        end

        context 'when changing from buildpack to docker' do
          let(:process) { ProcessModel.make(app: AppModel.make(:buildpack)) }
          let(:app) { process.app }

          it 'raises an error' do
            request_attrs = { 'docker_image' => 'repo/great-image' }

            expect {
              app_update.update(app, process, request_attrs)
            }.to raise_error(/Lifecycle type cannot be changed/)
          end
        end
      end

      describe 'updating docker_image' do
        let(:process) { ProcessModelFactory.make(app: AppModel.make(:docker), docker_image: 'repo/original-image') }
        let!(:original_package) { process.latest_package }
        let(:app_stage) { instance_double(V2::AppStage, stage: nil) }

        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
          allow(V2::AppStage).to receive(:new).and_return(app_stage)
        end

        it 'creates a new docker package' do
          request_attrs = { 'docker_image' => 'repo/new-image' }

          expect(process.docker_image).not_to eq('repo/new-image')
          app_update.update(process.app, process, request_attrs)

          expect(process.reload.docker_image).to eq('repo/new-image')
          expect(process.latest_package).not_to eq(original_package)
        end

        context 'when docker credentials are requested' do
          it 'creates a new docker package with those credentials' do
            request_attrs = {
              'docker_image'       => 'repo/new-image',
              'docker_credentials' => { 'username' => 'bob', 'password' => 'secret' }
            }

            expect(process.docker_image).not_to eq('repo/new-image')
            expect(process.docker_username).to be_nil
            expect(process.docker_password).to be_nil
            app_update.update(process.app, process, request_attrs)

            expect(process.reload.docker_image).to eq('repo/new-image')
            expect(process.docker_username).to eq('bob')
            expect(process.docker_password).to eq('secret')
            expect(process.latest_package).not_to eq(original_package)
          end
        end

        context 'when the same docker image is requested' do
          context 'but there are no changes' do
            it 'does not create a new package and does not trigger staging' do
              request_attrs = { 'docker_image' => 'REPO/ORIGINAL-IMAGE', 'state' => 'STARTED' }

              app_update.update(process.app, process, request_attrs)

              expect(process.reload.docker_image).to eq('repo/original-image')
              expect(process.latest_package).to eq(original_package)
              expect(process.needs_staging?).to be_falsey
            end
          end

          context 'but it changes credentials' do
            it 'creates a new docker package and triggers staging' do
              request_attrs = {
                'docker_image'       => 'repo/original-image',
                'docker_credentials' => { 'username' => 'bob', 'password' => 'secret' },
                'state'              => 'STARTED',
              }

              expect(process.reload.docker_image).to eq('repo/original-image')
              expect(process.docker_username).to be_nil
              expect(process.docker_password).to be_nil
              app_update.update(process.app, process, request_attrs)

              expect(process.reload.docker_image).to eq('repo/original-image')
              expect(process.docker_username).to eq('bob')
              expect(process.docker_password).to eq('secret')
              expect(process.latest_package).not_to eq(original_package)
              expect(process.needs_staging?).to be_truthy
            end
          end
        end
      end

      describe 'updating docker_credentials' do
        let(:process) { ProcessModelFactory.make(app: AppModel.make(:docker), docker_image: 'repo/original-image') }
        let!(:original_package) { process.latest_package }
        let(:app_stage) { instance_double(V2::AppStage, stage: nil) }

        before do
          FeatureFlag.create(name: 'diego_docker', enabled: true)
          allow(V2::AppStage).to receive(:new).and_return(app_stage)
        end

        it 'creates a new docker package' do
          request_attrs = { 'docker_credentials' => {
            'username' => 'user', 'password' => 'secret' } }

          expect(process.docker_image).to eq('repo/original-image')
          expect(process.docker_username).to be_nil
          expect(process.docker_password).to be_nil
          app_update.update(process.app, process, request_attrs)

          expect(process.reload.docker_image).to eq('repo/original-image')
          expect(process.docker_username).to eq('user')
          expect(process.docker_password).to eq('secret')
          expect(process.latest_package).not_to eq(original_package)
        end

        context 'when docker_image is not requested and the app does not have a docker_image' do
          let(:process) { ProcessModelFactory.make(app: AppModel.make(:docker)) }

          it 'raises an error' do
            request_attrs = { 'docker_credentials' => {
              'username' => 'user', 'password' => 'secret' } }

            expect { app_update.update(process.app, process, request_attrs) }.to raise_error(CloudController::Errors::ApiError,
              /Docker credentials can only be supplied for apps with a 'docker_image'/)
          end
        end
      end

      describe 'staging' do
        let(:app_stage) { instance_double(V2::AppStage, stage: nil) }
        let(:process) { ProcessModelFactory.make(state: 'STARTED') }
        let(:app) { process.app }

        before do
          allow(V2::AppStage).to receive(:new).and_return(app_stage)
        end

        context 'when a state change is requested' do
          let(:request_attrs) { { 'state' => 'STARTED' } }

          context 'when the app needs staging' do
            before do
              PackageModel.make(app: app, state: PackageModel::READY_STATE, package_hash: 'some-hash')
              process.reload
            end

            it 'requests to be staged' do
              expect(process.needs_staging?).to be_truthy
              app_update.update(app, process, request_attrs)
              expect(app_stage).to have_received(:stage)
            end

            it 'unsets the current droplet' do
              expect(process.current_droplet).not_to be_nil
              app_update.update(app, process, request_attrs)
              expect(process.reload.current_droplet).to be_nil
            end
          end

          context 'when the app does not need staging' do
            it 'does not request to be staged' do
              expect(process.needs_staging?).to be_falsey
              app_update.update(app, process, request_attrs)
              expect(app_stage).not_to have_received(:stage)
            end

            it 'does not change the current droplet' do
              expect(process.current_droplet).not_to be_nil
              app_update.update(app, process, request_attrs)
              expect(process.reload.current_droplet).not_to be_nil
            end
          end
        end

        context 'when a state change is NOT requested' do
          let(:request_attrs) { { 'name' => 'definitely-not-changing-state' } }

          context 'when the app needs staging' do
            before do
              app.update(droplet: nil)
              process.reload
            end

            it 'does not request to be staged' do
              expect(process.needs_staging?).to be_truthy
              app_update.update(app, process, request_attrs)
              expect(app_stage).not_to have_received(:stage)
            end
          end

          context 'when the app does not need staging' do
            it 'does not request to be staged' do
              expect(process.needs_staging?).to be_falsey
              app_update.update(app, process, request_attrs)
              expect(app_stage).not_to have_received(:stage)
            end
          end
        end
      end

      context 'when starting an app without a package' do
        let(:process) { ProcessModel.make(instances: 1) }

        it 'raises an error' do
          expect {
            app_update.update(process.app, process, { 'state' => 'STARTED' })
          }.to raise_error(/bits have not been uploaded/)
        end

        context 'and there is a staged droplet' do
          before do
            process.app.update(droplet: DropletModel.make(app: process.app, state: DropletModel::STAGED_STATE))
          end

          it 'does not raise an error' do
            expect {
              app_update.update(process.app, process, { 'state' => 'STARTED' })
            }.not_to raise_error
          end
        end
      end

      describe 'starting and stopping' do
        let(:app) { process.app }
        let(:process) { ProcessModelFactory.make(instances: 1, state: state) }
        let(:sibling_process) { ProcessModel.make(instances: 1, state: state, app: app, type: 'worker') }

        context 'starting' do
          let(:state) { 'STOPPED' }

          it 'is reflected in the parent app and all sibling processes' do
            expect(app.desired_state).to eq('STOPPED')
            expect(process.state).to eq('STOPPED')
            expect(sibling_process.state).to eq('STOPPED')

            app_update.update(app, process, { 'state' => 'STARTED' })

            expect(app.reload.desired_state).to eq('STARTED')
            expect(process.reload.state).to eq('STARTED')
            expect(sibling_process.reload.state).to eq('STARTED')
          end
        end

        context 'stopping' do
          let(:state) { 'STARTED' }
          let(:stager) { instance_double(Diego::Stager) }

          before do
            allow(stagers).to receive(:stager_for_app).and_return(stager)
            allow(stager).to receive(:stop_stage)
          end

          it 'is reflected in the parent app and all sibling processes' do
            expect(app.desired_state).to eq('STARTED')
            expect(process.state).to eq('STARTED')
            expect(sibling_process.state).to eq('STARTED')

            app_update.update(app, process, { 'state' => 'STOPPED' })

            expect(app.reload.desired_state).to eq('STOPPED')
            expect(process.reload.state).to eq('STOPPED')
            expect(sibling_process.reload.state).to eq('STOPPED')
          end
        end

        context 'invalid state' do
          let(:state) { 'STOPPED' }

          it 'raises an error' do
            expect {
              app_update.update(app, process, { 'state' => 'ohio' })
            }.to raise_error(/state must be one of/)
          end
        end
      end
    end
  end
end
