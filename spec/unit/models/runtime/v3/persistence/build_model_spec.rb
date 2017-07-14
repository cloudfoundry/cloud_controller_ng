# encoding: utf-8

require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildModel do
    let(:package) { PackageModel.make(state: PackageModel::READY_STATE) }
    let(:build_model) { BuildModel.make(package: package) }
    let!(:lifecycle_data) do
      BuildpackLifecycleDataModel.make(
        build: build_model,
        buildpacks: ['http://some-buildpack.com', 'http://another-buildpack.net']
      )
    end

    before do
      build_model.buildpack_lifecycle_data = lifecycle_data
      build_model.save
    end

    describe 'associations' do
      it 'has a foreign key to app' do
        app = AppModel.make
        BuildModel.make(app: app)
        expect {
          app.delete
        }.to raise_error Sequel::ForeignKeyConstraintViolation
      end

      describe 'space' do
        it 'gets its space from the containing app' do
          space = Space.make
          app = AppModel.make(space: space)
          build = BuildModel.make(app: app)
          expect(build.space).to eq(space)
        end
      end
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
        expect(build_model.reload.lifecycle_data.buildpacks).to eq(lifecycle_data.buildpacks)
        expect(build_model.reload.lifecycle_data.stack).to eq(lifecycle_data.stack)
      end

      it 'returns a docker lifecycle model if there is no buildpack_lifecycle_model' do
        build_model.buildpack_lifecycle_data = nil
        build_model.save

        expect(build_model.lifecycle_data).to be_a(DockerLifecycleDataModel)
      end

      context 'buildpack dependencies' do
        it 'deletes the dependent buildpack_lifecycle_data_models when a build is deleted' do
          expect {
            build_model.destroy
          }.to change { BuildpackLifecycleDataModel.count }.by(-1).
            and change { BuildpackLifecycleBuildpackModel.count }.by(-2)
        end
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

      it 'creates an app usage event for STAGING_STOPPED' do
        expect {
          build_model.fail_to_stage!
        }.to change {
          AppUsageEvent.count
        }.by(1)

        event = AppUsageEvent.last
        expect(event).to_not be_nil
        expect(event.state).to eq('STAGING_STOPPED')
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

    describe '#mark_as_staged' do
      before { build_model.update(state: BuildModel::STAGING_STATE) }

      it 'sets the sate to STAGED' do
        expect { build_model.mark_as_staged }.to change { build_model.state }.to(BuildModel::STAGED_STATE)
      end

      it 'creates an app usage event for STAGING_STOPPED' do
        expect {
          build_model.mark_as_staged
        }.to change {
          AppUsageEvent.count
        }.by(1)

        event = AppUsageEvent.last
        expect(event).to_not be_nil
        expect(event.state).to eq('STAGING_STOPPED')
      end
    end

    describe '#record_staging_stopped' do
      before { build_model.update(state: BuildModel::STAGING_STATE) }

      it 'creates an app usage event for STAGING_STOPPED' do
        expect {
          build_model.record_staging_stopped
        }.to change {
          AppUsageEvent.count
        }.by(1)

        event = AppUsageEvent.last
        expect(event).to_not be_nil
        expect(event.state).to eq('STAGING_STOPPED')
        expect(event.previous_state).to eq('STAGING')
        expect(event.instance_count).to eq(1)
        expect(event.previous_instance_count).to eq(1)
        expect(event.memory_in_mb_per_instance).to eq(BuildModel::STAGING_MEMORY)
        expect(event.previous_memory_in_mb_per_instance).to eq(BuildModel::STAGING_MEMORY)

        expect(event.org_guid).to eq(build_model.app.space.organization.guid)
        expect(event.space_guid).to eq(build_model.app.space.guid)
        expect(event.parent_app_guid).to eq(build_model.app.guid)
        expect(event.parent_app_name).to eq(build_model.app.name)
        expect(event.package_guid).to eq(build_model.package_guid)
        expect(event.app_name).to eq('')
        expect(event.app_guid).to eq('')
        expect(event.package_state).to eq(PackageModel::READY_STATE)
        expect(event.previous_package_state).to eq(PackageModel::READY_STATE)

        expect(event.buildpack_guid).to eq(nil)
        expect(event.buildpack_name).to eq('http://some-buildpack.com')
      end
    end
  end
end
