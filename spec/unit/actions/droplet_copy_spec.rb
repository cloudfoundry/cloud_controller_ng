require 'spec_helper'
require 'actions/droplet_copy'

module VCAP::CloudController
  RSpec.describe DropletCopy do
    let(:droplet_copy) { DropletCopy.new(source_droplet) }
    let(:source_space) { VCAP::CloudController::Space.make }
    let!(:target_app) { VCAP::CloudController::AppModel.make(name: 'target-app-name') }
    let!(:source_app) { VCAP::CloudController::AppModel.make(name: 'source-app-name', space: source_space) }
    let(:lifecycle_type) { :buildpack }
    let!(:source_droplet) do
      VCAP::CloudController::DropletModel.make(lifecycle_type,
        app_guid:              source_app.guid,
        droplet_hash:          'abcdef',
        sha256_checksum:          'droplet-sha256-checksum',
        process_types:         { web: 'bundle exec rails s' },
        buildpack_receipt_buildpack_guid: 'buildpack-guid',
        buildpack_receipt_buildpack: 'buildpack',
        state:                 VCAP::CloudController::DropletModel::STAGED_STATE,
        execution_metadata: 'execution_metadata',
        docker_receipt_image: 'docker/image',
        docker_receipt_username: 'dockerusername',
        docker_receipt_password: 'dockerpassword',
       )
    end
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'user-email', user_guid: 'user_guid') }

    describe '#copy' do
      it 'copies the passed in droplet to the target app' do
        expect {
          droplet_copy.copy(target_app, user_audit_info)
        }.to change { DropletModel.count }.by(1)

        copied_droplet = DropletModel.last

        expect(copied_droplet.state).to eq DropletModel::COPYING_STATE
        expect(copied_droplet.droplet_hash).to be nil
        expect(copied_droplet.sha256_checksum).to be nil
        expect(copied_droplet.process_types).to eq({ 'web' => 'bundle exec rails s' })
        expect(copied_droplet.buildpack_receipt_buildpack_guid).to eq 'buildpack-guid'
        expect(copied_droplet.buildpack_receipt_buildpack).to eq 'buildpack'
        expect(copied_droplet.execution_metadata).to eq 'execution_metadata'
        expect(copied_droplet.docker_receipt_image).to eq 'docker/image'
        expect(copied_droplet.docker_receipt_username).to eq 'dockerusername'
        expect(copied_droplet.docker_receipt_password).to eq 'dockerpassword'

        expect(target_app.droplets).to include(copied_droplet)
      end

      it 'creates an audit event' do
        expect(Repositories::DropletEventRepository).to receive(:record_create_by_copying).with(
          String, # the copied_droplet doesn't exist yet to know its guid
          source_droplet.guid,
          user_audit_info,
          target_app.guid,
          'target-app-name',
          target_app.space_guid,
          target_app.space.organization_guid
        )

        droplet_copy.copy(target_app, user_audit_info)
      end

      context 'when the source droplet is not STAGED' do
        before do
          source_droplet.update(state: DropletModel::FAILED_STATE)
        end

        it 'raises' do
          expect {
            droplet_copy.copy(target_app, user_audit_info)
          }.to raise_error(/source droplet is not staged/)
        end
      end

      context 'when lifecycle is buildpack' do
        it 'creates a buildpack_lifecycle_data record for the new droplet' do
          expect {
            droplet_copy.copy(target_app, user_audit_info)
          }.to change { BuildpackLifecycleDataModel.count }.by(1)

          copied_droplet = DropletModel.last

          expect(copied_droplet.buildpack_lifecycle_data.stack).not_to be nil
          expect(copied_droplet.buildpack_lifecycle_data.stack).to eq(source_droplet.buildpack_lifecycle_data.stack)
        end

        it 'enqueues a job to copy the droplet bits' do
          copied_droplet = nil

          expect {
            copied_droplet = droplet_copy.copy(target_app, user_audit_info)
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
            droplet_copy.copy(target_app, user_audit_info)
          }.to change { DropletModel.count }.by(1)

          copied_droplet = DropletModel.last

          expect(copied_droplet).to be_docker
          expect(copied_droplet.guid).to_not eq(source_droplet.guid)
          expect(copied_droplet.docker_receipt_image).to eq('urvashi/reddy')
          expect(copied_droplet.state).to eq(VCAP::CloudController::DropletModel::STAGED_STATE)
        end
      end
    end
  end
end
