require 'spec_helper'
require 'actions/app_start'

module VCAP::CloudController
  describe AppStart do
    let(:user) { double(:user, guid: '7') }
    let(:user_email) { '1@2.3' }
    let(:app_start) { AppStart.new(user, user_email) }

    describe '#start' do
      let(:environment_variables) { { 'FOO' => 'bar' } }
      let!(:process1) { App.make(state: 'STOPPED', app: app_model) }
      let!(:process2) { App.make(state: 'STOPPED', app: app_model) }

      let(:app_model) do
        AppModel.make({
          desired_state: 'STOPPED',
          droplet_guid: droplet_guid,
          environment_variables: environment_variables
        })
      end

      context 'when the droplet does not exist' do
        let(:droplet_guid) { nil }

        it 'raises a DropletNotFound exception' do
          expect {
            app_start.start(app_model)
          }.to raise_error(AppStart::DropletNotFound)
        end
      end

      context 'when the droplet exists' do
        let(:droplet) { DropletModel.make(state: DropletModel::STAGED_STATE, droplet_hash: 'the-hash') }
        let(:droplet_guid) { droplet.guid }

        it 'sets the desired state on the app' do
          app_start.start(app_model)
          expect(app_model.desired_state).to eq('STARTED')
        end

        it 'creates an audit event' do
          expect_any_instance_of(Repositories::Runtime::AppEventRepository).to receive(:record_app_start).with(
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
          let(:droplet) { DropletModel.make(package_guid: package.guid, state: DropletModel::STAGED_STATE) }
          let(:package) { PackageModel.make(package_hash: 'some-awesome-thing', state: PackageModel::READY_STATE) }

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

        context 'and the droplet does not have a package' do
          it 'sets the package hash to unknown' do
            app_start.start(app_model)

            process1.reload
            expect(process1.package_hash).to eq('unknown')
            expect(process1.package_state).to eq('STAGED')

            process2.reload
            expect(process2.package_hash).to eq('unknown')
            expect(process2.package_state).to eq('STAGED')
          end
        end

        it 'prepares the sub-processes of the app' do
          app_start.start(app_model)

          process1.reload
          expect(process1.needs_staging?).to eq(false)
          expect(process1.started?).to eq(true)
          expect(process1.state).to eq('STARTED')
          expect(process1.droplet_hash).to eq(droplet.droplet_hash)
          expect(process1.diego).to eq(true)
          expect(process1.environment_json).to eq(app_model.environment_variables)

          process2.reload
          expect(process2.needs_staging?).to eq(false)
          expect(process2.started?).to eq(true)
          expect(process2.state).to eq('STARTED')
          expect(process2.droplet_hash).to eq(droplet.droplet_hash)
          expect(process2.diego).to eq(true)
          expect(process2.environment_json).to eq(app_model.environment_variables)
        end
      end
    end
  end
end
