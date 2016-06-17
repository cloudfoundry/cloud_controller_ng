# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe DropletModel do
    it { is_expected.to validates_includes DropletModel::DROPLET_STATES, :state, allow_missing: true }

    describe '#blobstore_key' do
      let(:droplet) { DropletModel.make(droplet_hash: droplet_hash) }

      context 'when the droplet has been uploaded' do
        let(:droplet_hash) { 'foobar' }

        it 'returns the correct blobstore key' do
          expect(droplet.blobstore_key).to eq(File.join(droplet.guid, droplet_hash))
        end
      end

      context 'when the droplet has not been uploaded' do
        let(:droplet_hash) { nil }

        it 'returns nil' do
          expect(droplet.blobstore_key).to be_nil
        end
      end
    end

    describe '#staged?' do
      context 'when the droplet has been staged' do
        let!(:droplet_model) { DropletModel.make(state: 'STAGED') }

        it 'returns true' do
          expect(droplet_model.staged?).to be true
        end
      end

      context 'when the droplet has not been staged' do
        let!(:droplet_model) { DropletModel.make(state: 'PENDING') }

        it 'returns false' do
          expect(droplet_model.staged?).to be false
        end
      end
    end

    describe '#mark_as_staged' do
      let!(:droplet_model) { DropletModel.make }

      it 'changes the droplet state to STAGED' do
        droplet_model.mark_as_staged
        expect(droplet_model.state).to be DropletModel::STAGED_STATE
      end
    end

    describe 'process_types' do
      let(:droplet_model) { DropletModel.make }

      it 'is a persistable hash' do
        info                        = { web: 'started', worker: 'started' }
        droplet_model.process_types = info
        droplet_model.save
        expect(droplet_model.reload.process_types['web']).to eq('started')
        expect(droplet_model.reload.process_types['worker']).to eq('started')
      end
    end

    describe '#lifecycle_type' do
      let(:droplet_model) { DropletModel.make }
      let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(droplet: droplet_model) }

      before do
        droplet_model.buildpack_lifecycle_data = lifecycle_data
        droplet_model.save
      end

      it 'returns the string "buildpack" if buildpack_lifecycle_data is on the model' do
        expect(droplet_model.lifecycle_type).to eq('buildpack')
      end

      it 'returns the string "docker" if there is no buildpack_lifecycle_data is on the model' do
        droplet_model.buildpack_lifecycle_data = nil
        droplet_model.save

        expect(droplet_model.lifecycle_type).to eq('docker')
      end
    end

    describe '#lifecycle_data' do
      let(:droplet_model) { DropletModel.make }
      let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(droplet: droplet_model) }

      before do
        droplet_model.buildpack_lifecycle_data = lifecycle_data
        droplet_model.save
      end

      it 'returns buildpack_lifecycle_data if it is on the model' do
        expect(droplet_model.lifecycle_data).to eq(lifecycle_data)
      end

      it 'is a persistable hash' do
        expect(droplet_model.reload.lifecycle_data.buildpack).to eq(lifecycle_data.buildpack)
        expect(droplet_model.reload.lifecycle_data.stack).to eq(lifecycle_data.stack)
      end

      it 'returns a docker lifecycle model if there is no buildpack_lifecycle_model' do
        droplet_model.buildpack_lifecycle_data = nil
        droplet_model.save

        expect(droplet_model.lifecycle_data).to be_a(DockerLifecycleDataModel)
      end
    end

    describe '#update_buildpack_receipt' do
      let!(:droplet_model) { DropletModel.make(state: 'STAGED') }
      let(:buildpack) { Buildpack.make }
      let(:buildpack_key) { buildpack.key }

      it 'updates the buildpack receipt with the new buildpack and buildpack guid' do
        droplet_model.update_buildpack_receipt(buildpack_key)
        droplet_model.reload

        expect(droplet_model.buildpack_receipt_buildpack_guid).to eq(buildpack.guid)
        expect(droplet_model.buildpack_receipt_buildpack).to eq(buildpack.name)
      end

      context 'when there is no detected buildpack' do
        let(:old_buildpack) { Buildpack.make }
        before do
          droplet_model.update(
            buildpack_receipt_buildpack_guid: old_buildpack.guid,
            buildpack_receipt_buildpack: old_buildpack.name
          )
        end

        it 'does not update the buildpack receipt' do
          droplet_model.update_buildpack_receipt(nil)

          expect(droplet_model.buildpack_receipt_buildpack_guid).to eq(old_buildpack.guid)
          expect(droplet_model.buildpack_receipt_buildpack).to eq(old_buildpack.name)
        end
      end
    end

    describe 'usage events' do
      it 'ensures we have coverage for all states' do
        expect(DropletModel::DROPLET_STATES.count).to eq(5), 'After adding a new state, tests for app usage event coverage should be added.'
      end

      context 'when creating a droplet' do
        it 'creates a STAGING_STARTED app usage event' do
          expect {
            DropletModel.make
          }.to change { AppUsageEvent.count }.by(1)

          expect(AppUsageEvent.last.state).to eq('STAGING_STARTED')
        end
      end

      context 'when updating a droplet' do
        let!(:droplet) { DropletModel.make(state: initial_state) }

        context 'when state is PENDING' do
          let(:initial_state) { DropletModel::STAGING_STATE }

          it 'records no usage event' do
            expect {
              droplet.state = DropletModel::PENDING_STATE
              droplet.save
            }.not_to change { AppUsageEvent.count }
          end
        end

        context 'when state is STAGING' do
          let(:initial_state) { DropletModel::PENDING_STATE }

          it 'records no usage event' do
            expect {
              droplet.state = DropletModel::STAGING_STATE
              droplet.save
            }.not_to change { AppUsageEvent.count }
          end
        end

        context 'when state is FAILED' do
          context 'changing from a different state' do
            let(:initial_state) { DropletModel::PENDING_STATE }

            it 'records a STAGING_STOPPED event ' do
              expect {
                droplet.state = DropletModel::FAILED_STATE
                droplet.save
              }.to change { AppUsageEvent.count }.by(1)

              expect(AppUsageEvent.last.state).to eq('STAGING_STOPPED')
            end
          end

          context 'not changing state' do
            let(:initial_state) { DropletModel::FAILED_STATE }

            it 'records no usage event' do
              expect {
                droplet.staging_memory_in_mb = 555
                droplet.save
              }.not_to change { AppUsageEvent.count }
            end
          end
        end

        context 'when state is STAGED' do
          context 'changing from a different state' do
            let(:initial_state) { DropletModel::PENDING_STATE }

            it 'records a STAGING_STOPPED event ' do
              expect {
                droplet.state = DropletModel::STAGED_STATE
                droplet.save
              }.to change { AppUsageEvent.count }.by(1)

              expect(AppUsageEvent.last.state).to eq('STAGING_STOPPED')
            end
          end

          context 'not changing state' do
            let(:initial_state) { DropletModel::STAGED_STATE }

            it 'records no usage event' do
              expect {
                droplet.staging_memory_in_mb = 555
                droplet.save
              }.not_to change { AppUsageEvent.count }
            end
          end
        end

        context 'when state is EXPIRED' do
          let(:initial_state) { DropletModel::STAGED_STATE }

          it 'records no usage event' do
            expect {
              droplet.state = DropletModel::EXPIRED_STATE
              droplet.save
            }.not_to change { AppUsageEvent.count }
          end
        end
      end

      context 'when deleting a droplet' do
        let!(:droplet) { DropletModel.make(state: state) }

        context 'when state is PENDING' do
          let(:state) { DropletModel::PENDING_STATE }

          it 'records a STAGING_STOPPED event ' do
            expect {
              droplet.destroy
            }.to change { AppUsageEvent.count }.by(1)

            expect(AppUsageEvent.last.state).to eq('STAGING_STOPPED')
          end
        end

        context 'when state is STAGING' do
          let(:state) { DropletModel::STAGING_STATE }

          it 'records a STAGING_STOPPED event ' do
            expect {
              droplet.destroy
            }.to change { AppUsageEvent.count }.by(1)

            expect(AppUsageEvent.last.state).to eq('STAGING_STOPPED')
          end
        end

        context 'when state is FAILED' do
          let(:state) { DropletModel::FAILED_STATE }

          it 'records no usage event' do
            expect {
              droplet.destroy
            }.not_to change { AppUsageEvent.count }
          end
        end

        context 'when state is STAGED' do
          let(:state) { DropletModel::STAGED_STATE }

          it 'records no usage event' do
            expect {
              droplet.destroy
            }.not_to change { AppUsageEvent.count }
          end
        end

        context 'when state is EXPIRED' do
          let(:state) { DropletModel::EXPIRED_STATE }

          it 'records no usage event' do
            expect {
              droplet.destroy
            }.not_to change { AppUsageEvent.count }
          end
        end
      end
    end
  end
end
