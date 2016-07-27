require 'spec_helper'
require 'actions/app_start'

module VCAP::CloudController
  RSpec.describe AppStart do
    let(:user) { double(:user, guid: '7') }
    let(:user_email) { '1@2.3' }
    let(:app_start) { AppStart.new(user, user_email) }

    describe '#start' do
      let(:environment_variables) { { 'FOO' => 'bar' } }

      context 'when the app has a docker lifecycle' do
        let(:app_model) do
          AppModel.make(
            :docker,
            desired_state:         'STOPPED',
            environment_variables: environment_variables
          )
        end
        let(:package) { PackageModel.make(:docker, app: app_model, state: PackageModel::READY_STATE) }
        let!(:droplet) { DropletModel.make(:docker, app: app_model, package: package, state: DropletModel::STAGED_STATE, docker_receipt_image: package.image) }
        let!(:process1) { App.make(:process, state: 'STOPPED', app: app_model) }
        let!(:process2) { App.make(:process, state: 'STOPPED', app: app_model) }

        before do
          app_model.update(droplet: droplet)
          VCAP::CloudController::FeatureFlag.make(name: 'diego_docker', enabled: true, error_message: nil)
        end

        it 'starts the app' do
          app_start.start(app_model)
          expect(app_model.desired_state).to eq('STARTED')
        end

        it 'sets the docker image on the process' do
          app_start.start(app_model)

          process1.reload
          expect(process1.docker_image).to eq(droplet.docker_receipt_image)
        end
      end

      context 'when the app has a buildpack lifecycle' do
        let(:app_model) do
          AppModel.make(:buildpack,
            desired_state:         'STOPPED',
            environment_variables: environment_variables)
        end
        let!(:droplet) do
          DropletModel.make(
            app:          app_model,
            state:        DropletModel::STAGED_STATE,
            droplet_hash: 'the-hash'
          )
        end
        let!(:process1) { App.make(:process, state: 'STOPPED', app: app_model) }
        let!(:process2) { App.make(:process, state: 'STOPPED', app: app_model) }

        before do
          app_model.update(droplet: droplet)
        end

        it 'sets the desired state on the app' do
          app_start.start(app_model)
          expect(app_model.desired_state).to eq('STARTED')
        end

        it 'creates an audit event' do
          expect_any_instance_of(Repositories::AppEventRepository).to receive(:record_app_start).with(
            app_model,
            user.guid,
            user_email
          )

          app_start.start(app_model)
        end

        context 'when the app is invalid' do
          before do
            allow_any_instance_of(AppModel).to receive(:update).and_raise(Sequel::ValidationFailed.new('some message'))
          end

          it 'raises a InvalidApp exception' do
            expect {
              app_start.start(app_model)
            }.to raise_error(AppStart::InvalidApp, 'some message')
          end
        end

        context 'and the droplet has a package' do
          let!(:droplet) do
            DropletModel.make(
              app:     app_model,
              package: package,
              state:   DropletModel::STAGED_STATE,
            )
          end
          let(:package) { PackageModel.make(app: app_model, package_hash: 'some-awesome-thing', state: PackageModel::READY_STATE) }

          it 'sets the package hash correctly on the process' do
            app_start.start(app_model)

            process1.reload
            expect(process1.package_hash).to eq(package.package_hash)
            expect(process1.package_state).to eq('STAGED')

            process2.reload
            expect(process2.package_hash).to eq(package.package_hash)
            expect(process2.package_state).to eq('STAGED')
          end
        end
      end
    end
  end
end
