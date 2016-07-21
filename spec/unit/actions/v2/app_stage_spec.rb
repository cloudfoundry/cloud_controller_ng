require 'spec_helper'
require 'actions/v2/app_stage'

module VCAP::CloudController
  module V2
    RSpec.describe AppStage do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }
      let(:stagers) { instance_double(Stagers, validate_app: nil) }

      subject(:action) { described_class.new(user: user, user_email: user_email, stagers: stagers) }

      describe '#stage' do
        let(:droplet_create) { instance_double(DropletCreate, create_and_stage: nil, staging_response: 'staging-response') }

        before do
          allow(DropletCreate).to receive(:new).and_return(droplet_create)
        end

        it 'delegates to DropletCreate with a DropletCreateMessage based on the process' do
          process = App.make(memory: 765, disk_quota: 1234)
          package = PackageModel.make(app: process.app, state: PackageModel::READY_STATE)
          process.reload

          action.stage(process)

          expect(droplet_create).to have_received(:create_and_stage) do |pkg, _lifecycle, message, _start_after_staging|
            expect(pkg).to eq(package)
            expect(message.staging_memory_in_mb).to eq(765)
            expect(message.staging_disk_in_mb).to eq(1234)
          end
        end

        it 'requests to start the app after staging' do
          process = AppFactory.make(memory: 765, disk_quota: 1234)

          action.stage(process)

          expect(droplet_create).to have_received(:create_and_stage) do |_pkg, _lifecycle, _message, start_after_staging|
            expect(start_after_staging).to be_truthy
          end
        end

        it 'provides a docker lifecycle for docker apps' do
          process = AppFactory.make(docker_image: 'some-image')

          action.stage(process)

          expect(droplet_create).to have_received(:create_and_stage) do |_pkg, lifecycle, _message, _start_after_staging|
            expect(lifecycle.type).to equal(Lifecycles::DOCKER)
          end
        end

        it 'provides a buildpack lifecyle for buildpack apps' do
          process = AppFactory.make

          action.stage(process)

          expect(droplet_create).to have_received(:create_and_stage) do |_pkg, lifecycle, _message, _start_after_staging|
            expect(lifecycle.type).to equal(Lifecycles::BUILDPACK)
          end
        end

        it 'attaches the staging response to the app' do
          process = AppFactory.make
          action.stage(process)
          expect(process.last_stager_response).to eq('staging-response')
        end

        it 'validates the app before staging' do
          process = AppFactory.make
          allow(stagers).to receive(:validate_app).with(process).and_raise(StandardError.new)

          expect {
            action.stage(process)
          }.to raise_error(StandardError)

          expect(droplet_create).not_to have_received(:create_and_stage)
        end
      end
    end
  end
end
