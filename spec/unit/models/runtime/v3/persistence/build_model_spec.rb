# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildModel do
    let(:build_model) { BuildModel.make }
    let!(:lifecycle_data) { BuildpackLifecycleDataModel.make(build: build_model) }

    before do
      build_model.buildpack_lifecycle_data = lifecycle_data
      build_model.save
    end

    describe '#lifecycle_type' do
      it 'returns the string "buildpack" if buildpack_lifecycle_data is on the model' do
        expect(build_model.lifecycle_type).to eq('buildpack')
      end

      it 'returns the string "docker" if there is no buildpack_lifecycle_data is on the model' do
        build_model.buildpack_lifecycle_data = nil
        build_model.save

        expect(build_model.lifecycle_type).to eq('docker')
      end
    end

    describe '#lifecycle_data' do
      it 'returns buildpack_lifecycle_data if it is on the model' do
        expect(build_model.lifecycle_data).to eq(lifecycle_data)
      end

      it 'is a persistable hash' do
        expect(build_model.reload.lifecycle_data.buildpack).to eq(lifecycle_data.buildpack)
        expect(build_model.reload.lifecycle_data.stack).to eq(lifecycle_data.stack)
      end

      it 'returns a docker lifecycle model if there is no buildpack_lifecycle_model' do
        build_model.buildpack_lifecycle_data = nil
        build_model.save

        expect(build_model.lifecycle_data).to be_a(DockerLifecycleDataModel)
      end
    end

    describe '#staged?' do
      it 'returns true when state is STAGED' do
        build_model.state = BuildModel::STAGED_STATE
        expect(build_model.staged?).to eq(true)
      end

      it 'returns false otherwise' do
        build_model.state = BuildModel::FAILED_STATE
        expect(build_model.staged?).to eq(false)
      end
    end

    describe '#failed?' do
      it 'returns true when state is FAILED' do
        build_model.state = BuildModel::FAILED_STATE
        expect(build_model.failed?).to eq(true)
      end

      it 'returns false otherwise' do
        build_model.state = BuildModel::STAGING_STATE
        expect(build_model.failed?).to eq(false)
      end
    end

    describe '#staging?' do
      it 'returns true when state is STAGING' do
        build_model.state = BuildModel::STAGING_STATE
        expect(build_model.staging?).to eq(true)
      end

      it 'returns false otherwise' do
        build_model.state = BuildModel::FAILED_STATE
        expect(build_model.staging?).to eq(false)
      end
    end

    describe '#fail_to_stage!' do
      before { build_model.update(state: BuildModel::STAGING_STATE) }

      it 'sets the state to FAILED' do
        expect { build_model.fail_to_stage! }.to change { build_model.state }.to(BuildModel::FAILED_STATE)
      end

      context 'when a valid reason is specified' do
        BuildModel::STAGING_FAILED_REASONS.each do |reason|
          it 'sets the requested staging failed reason' do
            expect {
              build_model.fail_to_stage!(reason)
            }.to change { build_model.error_id }.to(reason)
          end
        end
      end

      context 'when an unexpected reason is specifed' do
        it 'should use the default, generic reason' do
          expect {
            build_model.fail_to_stage!('bogus')
          }.to change { build_model.error_id }.to('StagingError')
        end
      end

      context 'when a reason is not specified' do
        it 'should use the default, generic reason' do
          expect {
            build_model.fail_to_stage!
          }.to change { build_model.error_id }.to('StagingError')
        end
      end

      describe 'setting staging_failed_description' do
        it 'sets the staging_failed_description to the v2.yml description of the error type' do
          expect {
            build_model.fail_to_stage!('NoAppDetectedError')
          }.to change { build_model.error_description }.to('An app was not successfully detected by any available buildpack')
        end

        it 'provides a string for interpolation on errors that require it' do
          expect {
            build_model.fail_to_stage!('StagingError')
          }.to change { build_model.error_description }.to('Staging error: staging failed')
        end

        BuildModel::STAGING_FAILED_REASONS.each do |reason|
          it "successfully sets staging_failed_description for reason: #{reason}" do
            expect {
              build_model.fail_to_stage!(reason)
            }.to_not raise_error
          end
        end
      end
    end
  end
end
