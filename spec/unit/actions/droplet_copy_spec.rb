require 'spec_helper'
require 'actions/droplet_copy'

module VCAP::CloudController
  describe DropletCopy do
    let(:droplet_copy) { DropletCopy.new(source_droplet) }
    let(:source_space) { VCAP::CloudController::Space.make }
    let(:target_app) { VCAP::CloudController::AppModel.make }
    let(:source_app_guid) { VCAP::CloudController::AppModel.make(space_guid: source_space.guid) }
    let(:lifecycle_type) { :buildpack }
    let!(:source_droplet) { VCAP::CloudController::DropletModel.make(lifecycle_type,
      app_guid: source_app_guid,
      droplet_hash: 'abcdef',
      process_types: { web: 'bundle exec rails s' },
      environment_variables: { 'THING' => 'STUFF' })
    }

    describe '#copy' do
      it 'copies the passed in droplet to the target app' do
        expect {
          droplet_copy.copy(target_app.guid)
        }.to change { DropletModel.count }.by(1)

        copied_droplet = DropletModel.last

        expect(copied_droplet.state).to eq DropletModel::PENDING_STATE
        expect(copied_droplet.buildpack_receipt_buildpack_guid).to eq source_droplet.buildpack_receipt_buildpack_guid
        expect(copied_droplet.droplet_hash).to be nil
        expect(copied_droplet.detected_start_command).to eq source_droplet.detected_start_command
        expect(copied_droplet.environment_variables).to eq({ 'THING' => 'STUFF' })
        expect(copied_droplet.process_types).to eq({ 'web' => 'bundle exec rails s' })
        expect(copied_droplet.buildpack_receipt_buildpack).to eq source_droplet.buildpack_receipt_buildpack
        expect(copied_droplet.buildpack_receipt_stack_name).to eq source_droplet.buildpack_receipt_stack_name
        expect(copied_droplet.execution_metadata).to eq source_droplet.execution_metadata
        expect(copied_droplet.memory_limit).to eq source_droplet.memory_limit
        expect(copied_droplet.disk_limit).to eq source_droplet.disk_limit
        expect(copied_droplet.docker_receipt_image).to eq source_droplet.docker_receipt_image

        expect(target_app.droplets).to include(copied_droplet)
      end

      context 'when lifecycle is buildpack' do
        it 'creates a buildpack_lifecycle_data record for the new droplet' do
          expect {
            droplet_copy.copy(target_app.guid)
          }.to change { BuildpackLifecycleDataModel.count }.by(1)

          copied_droplet = DropletModel.last

          expect(copied_droplet.buildpack_lifecycle_data.stack).not_to be nil
          expect(copied_droplet.buildpack_lifecycle_data.stack).to eq(source_droplet.buildpack_lifecycle_data.stack)
        end

        it 'enqueues a job to copy the droplet bits' do
          copied_droplet = nil

          expect {
            copied_droplet = droplet_copy.copy(target_app.guid)
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

        it 'raises an ApiError' do
          expect {
            droplet_copy.copy(target_app.guid)
          }.to raise_error(CloudController::Errors::ApiError)
        end
      end
    end
  end
end
