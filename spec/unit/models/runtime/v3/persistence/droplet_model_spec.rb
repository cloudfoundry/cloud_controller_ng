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
        let!(:droplet_model) { DropletModel.make(state: 'STAGING') }

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

    describe '#set_buildpack_receipt' do
      let!(:droplet_model) { DropletModel.make(state: 'STAGED') }

      it 'records the output of the detect script' do
        droplet_model.set_buildpack_receipt(buildpack_key: nil, requested_buildpack: nil, detect_output: 'detect-output')
        expect(droplet_model.buildpack_receipt_detect_output).to eq('detect-output')
      end

      describe 'admin buildpack' do
        let(:buildpack) { Buildpack.make }
        let(:buildpack_key) { buildpack.key }

        it 'records the admin buildpack info' do
          droplet_model.set_buildpack_receipt(buildpack_key: buildpack_key, requested_buildpack: nil, detect_output: nil)
          expect(droplet_model.buildpack_receipt_buildpack_guid).to eq(buildpack.guid)
          expect(droplet_model.buildpack_receipt_buildpack).to eq(buildpack.name)
        end
      end

      describe 'custom buildpack' do
        it 'records the custom buildpack info' do
          droplet_model.set_buildpack_receipt(buildpack_url: 'http://buildpack.example.com', buildpack_key: nil, requested_buildpack: nil, detect_output: nil)
          expect(droplet_model.buildpack_receipt_buildpack).to eq('http://buildpack.example.com')
        end

        context 'when buildpack_url contains username and password' do
          it 'obfuscates the username and password' do
            droplet_model.set_buildpack_receipt(buildpack_url: 'https://amelia:meow@neopets.com', buildpack_key: nil, requested_buildpack: nil, detect_output: nil)
            expect(droplet_model.buildpack_receipt_buildpack).to eq('https://***:***@neopets.com')
          end
        end

        context 'when requested_buildpack contains username and password' do
          it 'obfuscates the username and password' do
            droplet_model.set_buildpack_receipt(buildpack_key: nil, requested_buildpack: 'https://amelia:meow@neopets.com', detect_output: nil)
            expect(droplet_model.buildpack_receipt_buildpack).to eq('https://***:***@neopets.com')
          end
        end
      end

      describe 'unknown buildpack from response' do
        it 'records the requested buildpack' do
          droplet_model.set_buildpack_receipt(buildpack_key: nil, requested_buildpack: 'requested-buildpack', detect_output: nil)
          expect(droplet_model.buildpack_receipt_buildpack).to eq('requested-buildpack')
        end
      end
    end

    describe '#fail_to_stage!' do
      subject(:droplet) { DropletModel.make(state: DropletModel::STAGING_STATE) }

      it 'sets the state to FAILED' do
        expect { droplet.fail_to_stage! }.to change { droplet.state }.to(DropletModel::FAILED_STATE)
      end

      context 'when a valid reason is specified' do
        DropletModel::STAGING_FAILED_REASONS.each do |reason|
          it 'sets the requested staging failed reason' do
            expect {
              droplet.fail_to_stage!(reason)
            }.to change { droplet.error_id }.to(reason)
          end
        end
      end

      context 'when an unexpected reason is specifed' do
        it 'should use the default, generic reason' do
          expect {
            droplet.fail_to_stage!('bogus')
          }.to change { droplet.error_id }.to('StagingError')
        end
      end

      context 'when a reason is not specified' do
        it 'should use the default, generic reason' do
          expect {
            droplet.fail_to_stage!
          }.to change { droplet.error_id }.to('StagingError')
        end
      end

      describe 'setting staging_failed_description' do
        it 'sets the staging_failed_description to the v2.yml description of the error type' do
          expect {
            droplet.fail_to_stage!('NoAppDetectedError')
          }.to change { droplet.error_description }.to('An app was not successfully detected by any available buildpack')
        end

        it 'provides a string for interpolation on errors that require it' do
          expect {
            droplet.fail_to_stage!('StagingError')
          }.to change { droplet.error_description }.to('Staging error: staging failed')
        end

        DropletModel::STAGING_FAILED_REASONS.each do |reason|
          it "successfully sets staging_failed_description for reason: #{reason}" do
            expect {
              droplet.fail_to_stage!(reason)
            }.to_not raise_error
          end
        end
      end
    end

    describe 'usage events' do
      it 'ensures we have coverage for all states' do
        expect(DropletModel::DROPLET_STATES.count).to eq(6), 'After adding a new state, tests for app usage event coverage should be added.'
      end

      context 'when creating a droplet' do
        it 'creates a STAGING_STARTED app usage event' do
          expect {
            DropletModel.make
          }.to change { AppUsageEvent.count }.by(1)

          expect(AppUsageEvent.last.state).to eq('STAGING_STARTED')
        end

        context 'when state is COPYING' do
          it 'does not record an event' do
            expect {
              DropletModel.new(state: DropletModel::COPYING_STATE).save
            }.not_to change { AppUsageEvent.count }.from(0)
          end
        end

        context 'when state is PROCESSING_UPLOAD' do
          it 'does not record an event' do
            expect {
              DropletModel.new(state: DropletModel::PROCESSING_UPLOAD_STATE).save
            }.not_to change { AppUsageEvent.count }.from(0)
          end
        end
      end

      context 'when updating a droplet' do
        let!(:droplet) { DropletModel.make(state: initial_state) }

        context 'when state is FAILED' do
          context 'changing from a different state' do
            let(:initial_state) { DropletModel::STAGING_STATE }

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
            let(:initial_state) { DropletModel::STAGING_STATE }

            it 'records a STAGING_STOPPED event ' do
              expect {
                droplet.state = DropletModel::STAGED_STATE
                droplet.save
              }.to change { AppUsageEvent.count }.by(1)

              expect(AppUsageEvent.last.state).to eq('STAGING_STOPPED')
            end

            context 'but the initial state is PROCESSING_UPLOAD' do
              let(:initial_state) { DropletModel::PROCESSING_UPLOAD_STATE }

              it 'records no STAGING_STOPPED event ' do
                expect {
                  droplet.state = DropletModel::STAGED_STATE
                  droplet.save
                }.not_to change { AppUsageEvent.count }
              end
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

        context 'when state is COPYING' do
          let(:state) { DropletModel::COPYING_STATE }

          it 'records no usage event' do
            expect {
              droplet.destroy
            }.not_to change { AppUsageEvent.count }
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

        context 'when state is PROCESSING_UPLOAD' do
          let(:state) { DropletModel::PROCESSING_UPLOAD_STATE }

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
