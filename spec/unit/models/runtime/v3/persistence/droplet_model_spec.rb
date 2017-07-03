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
        expect(droplet_model.state).to eq(DropletModel::STAGED_STATE)
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
      let!(:lifecycle_data) do
        BuildpackLifecycleDataModel.make(
          droplet: droplet_model,
          buildpacks: ['http://some-buildpack.com', 'http://another-buildpack.net']
        )
      end

      before do
        droplet_model.buildpack_lifecycle_data = lifecycle_data
        droplet_model.save
      end

      it 'returns buildpack_lifecycle_data if it is on the model' do
        expect(droplet_model.lifecycle_data).to eq(lifecycle_data)
      end

      it 'is a persistable hash' do
        expect(droplet_model.reload.lifecycle_data.buildpacks).to eq(lifecycle_data.buildpacks)
        expect(droplet_model.reload.lifecycle_data.stack).to eq(lifecycle_data.stack)
      end

      it 'returns a docker lifecycle model if there is no buildpack_lifecycle_model' do
        droplet_model.buildpack_lifecycle_data = nil
        droplet_model.save

        expect(droplet_model.lifecycle_data).to be_a(DockerLifecycleDataModel)
      end

      context 'buildpack dependencies' do
        it 'deletes the dependent buildpack_lifecycle_data_models when a build is deleted' do
          expect {
            droplet_model.destroy
          }.to change { BuildpackLifecycleDataModel.count }.by(-1).
            and change { BuildpackLifecycleBuildpackModel.count }.by(-2)
        end
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

    describe '#droplet_checksum' do
      let!(:droplet_model_with_both) { DropletModel.make(sha256_checksum: 'foo', droplet_hash: 'bar') }
      let!(:droplet_model_with_only_sha1) { DropletModel.make(sha256_checksum: nil, droplet_hash: 'baz') }

      it 'returns the sha256_checksum when present' do
        expect(droplet_model_with_both.checksum).to eq('foo')
      end

      it 'returns the sha1 checksum when there is no sha256' do
        expect(droplet_model_with_only_sha1.checksum).to eq('baz')
      end
    end

    describe '#buildpack_receipt_stack_name' do
      it_should_be_removed(
        by: '2017/11/20',
        explanation: "It's been six months since we stopped using #buildpack_receipt_stack_name... drop the column",
      )
    end
  end
end
