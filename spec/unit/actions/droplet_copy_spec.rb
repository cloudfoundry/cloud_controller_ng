require 'spec_helper'
require 'actions/droplet_copy'

module VCAP::CloudController
  RSpec.describe DropletCopy do
    let(:droplet_copy) { DropletCopy.new(source_droplet) }
    let(:source_space) { VCAP::CloudController::Space.make }
    let(:target_app) { VCAP::CloudController::AppModel.make(name: 'target-app-name') }
    let(:source_app) { VCAP::CloudController::AppModel.make(name: 'source-app-name', space_guid: source_space.guid) }
    let(:lifecycle_type) { :buildpack }
    let!(:source_droplet) { VCAP::CloudController::DropletModel.make(lifecycle_type,
      app_guid: source_app.guid,
      droplet_hash: 'abcdef',
      process_types: { web: 'bundle exec rails s' },
      environment_variables: { 'THING' => 'STUFF' },
      state: VCAP::CloudController::DropletModel::STAGING_STATE)
    }

    describe '#copy' do
      it 'copies the passed in droplet to the target app' do
        expect {
          droplet_copy.copy(target_app, 'user-guid', 'user-email')
        }.to change { DropletModel.count }.by(1)

        copied_droplet = DropletModel.last

        expect(copied_droplet.state).to eq DropletModel::PENDING_STATE
        expect(copied_droplet.buildpack_receipt_buildpack_guid).to eq source_droplet.buildpack_receipt_buildpack_guid
        expect(copied_droplet.droplet_hash).to be nil
        expect(copied_droplet.detected_start_command).to eq source_droplet.detected_start_command
        expect(copied_droplet.environment_variables).to eq(nil)
        expect(copied_droplet.process_types).to eq({ 'web' => 'bundle exec rails s' })
        expect(copied_droplet.buildpack_receipt_buildpack).to eq source_droplet.buildpack_receipt_buildpack
        expect(copied_droplet.buildpack_receipt_stack_name).to eq source_droplet.buildpack_receipt_stack_name
        expect(copied_droplet.execution_metadata).to eq source_droplet.execution_metadata
        expect(copied_droplet.staging_memory_in_mb).to eq source_droplet.staging_memory_in_mb
        expect(copied_droplet.staging_disk_in_mb).to eq source_droplet.staging_disk_in_mb
        expect(copied_droplet.docker_receipt_image).to eq source_droplet.docker_receipt_image

        expect(target_app.droplets).to include(copied_droplet)
      end

      it 'creates an audit event' do
        expect(Repositories::DropletEventRepository).to receive(:record_create_by_copying).with(
          String, # the copied_droplet doesn't exist yet to know its guid
          source_droplet.guid,
          'user-guid',
          'user-email',
          target_app.guid,
          'target-app-name',
          target_app.space_guid,
          target_app.space.organization_guid
        )

        droplet_copy.copy(target_app, 'user-guid', 'user-email')
      end

      context 'when lifecycle is buildpack' do
        it 'creates a buildpack_lifecycle_data record for the new droplet' do
          expect {
            droplet_copy.copy(target_app, 'user-guid', 'user-email')
          }.to change { BuildpackLifecycleDataModel.count }.by(1)

          copied_droplet = DropletModel.last

          expect(copied_droplet.buildpack_lifecycle_data.stack).not_to be nil
          expect(copied_droplet.buildpack_lifecycle_data.stack).to eq(source_droplet.buildpack_lifecycle_data.stack)
        end

        it 'enqueues a job to copy the droplet bits' do
          copied_droplet = nil

          expect {
            copied_droplet = droplet_copy.copy(target_app, 'user-guid', 'user-email')
          }.to change { Delayed::Job.count }.by(1)

          job = Delayed::Job.last
          expect(job.queue).to eq('cc-generic')
          expect(job.handler).to include(copied_droplet.guid)
          expect(job.handler).to include(source_droplet.guid)
          expect(job.handler).to include('DropletBitsCopier')
        end
      end

      context 'when lifecycle is docker' do
        let(:lifecycle_type) { :docker }

        before do
          source_droplet.update(docker_receipt_image: 'urvashi/reddy')
        end

        it 'copies a docker droplet' do
          expect {
            droplet_copy.copy(target_app, 'user-guid', 'user-email')
          }.to change { DropletModel.count }.by(1)

          copied_droplet = DropletModel.last

          expect(copied_droplet).to be_docker
          expect(copied_droplet.guid).to_not eq(source_droplet.guid)
          expect(copied_droplet.docker_receipt_image).to eq('urvashi/reddy')
          expect(copied_droplet.state).to eq(VCAP::CloudController::DropletModel::STAGING_STATE)
        end
      end
    end
  end
end
