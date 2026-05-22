require 'spec_helper'

module VCAP::CloudController
  RSpec.describe BuildModel do
    let(:package) { create(:package_model, state: PackageModel::READY_STATE) }
    let(:build_model) { create(:build_model, package:) }

    describe 'associations' do
      let!(:buildpack_lifecycle_data) do
        create(:buildpack_lifecycle_data_model, build: build_model,
                                                buildpacks: ['http://some-buildpack.com', 'http://another-buildpack.net'])
      end

      before do
        build_model.buildpack_lifecycle_data = buildpack_lifecycle_data
        build_model.save
      end

      it 'has a foreign key to app' do
        app = create(:app_model)
        create(:build_model, app:)
        expect do
          app.delete
        end.to raise_error Sequel::ForeignKeyConstraintViolation
      end

      describe 'space' do
        let!(:buildpack_lifecycle_data) do
          create(:buildpack_lifecycle_data_model, build: build_model,
                                                  buildpacks: ['http://some-buildpack.com', 'http://another-buildpack.net'])
        end

        before do
          build_model.buildpack_lifecycle_data = buildpack_lifecycle_data
          build_model.save
        end

        it 'gets its space from the containing app' do
          space = create(:space)
          app = create(:app_model, space:)
          build = create(:build_model, app:)
          expect(build.space).to eq(space)
        end
      end
    end

    describe '#lifecycle_type' do
      before do
        # Remove lifecycle type to test fallback mechanism based on associated lifecycle data
        build_model.update(lifecycle_type: '')
      end

      context 'when there is buildpack_lifecycle_data associated to the build' do
        let(:build_model) { create(:build_model, app: nil) }

        it 'returns the string "buildpack"' do
          expect(build_model.lifecycle_type).to eq('buildpack')
        end
      end

      context 'when there is cnb_lifecycle_data associated to the build' do
        let(:build_model) { create(:build_model, :cnb, app: nil) }

        it 'returns the string "cnb"' do
          expect(build_model.lifecycle_type).to eq('cnb')
        end
      end

      context 'when there is no lifecycle data associated to the build' do
        let(:build_model) { create(:build_model, :docker, app: nil) }

        it 'returns the string "docker"' do
          expect(build_model.lifecycle_type).to eq('docker')
        end
      end
    end

    describe '#before_create' do
      it 'inherits lifecycle_type from app if not set' do
        app = create(:app_model, :cnb)
        build = BuildModel.create(app: app, state: BuildModel::STAGING_STATE)
        expect(build[:lifecycle_type]).to eq('cnb')
      end

      it 'uses explicit lifecycle_type if set' do
        app = create(:app_model)
        build = BuildModel.create(app: app, state: BuildModel::STAGING_STATE, lifecycle_type: 'docker')
        expect(build[:lifecycle_type]).to eq('docker')
      end
    end

    describe 'validations' do
      it 'validates lifecycle_type is one of buildpack, cnb, or docker' do
        expect do
          create(:build_model, lifecycle_type: 'invalid')
        end.to raise_error(Sequel::ValidationFailed, /lifecycle_type/)
      end

      it 'accepts valid lifecycle_type values' do
        %w[buildpack cnb docker].each do |type|
          expect do
            create(:build_model, lifecycle_type: type)
          end.not_to raise_error
        end
      end
    end

    describe '#lifecycle_data' do
      context 'buildpack_lifecycle_data' do
        let!(:build_model) { create(:build_model, app: nil) }

        it 'returns a buildpack lifecycle data model' do
          expect(build_model.lifecycle_data).to be_a(BuildpackLifecycleDataModel)
          expect(build_model.lifecycle_data).to eq(build_model.buildpack_lifecycle_data)
          expect(build_model.cnb_lifecycle_data).to be_nil
        end

        it 'deletes the dependent buildpack_lifecycle_data model when a build is deleted' do
          expect do
            build_model.destroy
          end.to change(BuildpackLifecycleDataModel, :count).by(-1)
        end
      end

      context 'cnb_lifecycle_data' do
        let!(:build_model) { create(:build_model, :cnb, app: nil) }

        it 'returns a cnb lifecycle data model' do
          expect(build_model.lifecycle_data).to be_a(CNBLifecycleDataModel)
          expect(build_model.lifecycle_data).to eq(build_model.cnb_lifecycle_data)
          expect(build_model.buildpack_lifecycle_data).to be_nil
        end

        it 'deletes the dependent cnb_lifecycle_data when a build is deleted' do
          expect do
            build_model.destroy
          end.to change(CNBLifecycleDataModel, :count).by(-1)
        end
      end

      context 'neither buildpack_lifecycle_data, nor cnb_lifecycle_data' do
        let(:build_model) { create(:build_model, :docker, app: nil) }

        it 'returns a docker lifecycle data model' do
          expect(build_model.lifecycle_data).to be_a(DockerLifecycleDataModel)
          expect(build_model.buildpack_lifecycle_data).to be_nil
          expect(build_model.cnb_lifecycle_data).to be_nil
        end
      end
    end

    describe '#staged?' do
      it 'returns true when state is STAGED' do
        build_model.state = BuildModel::STAGED_STATE
        expect(build_model.staged?).to be(true)
      end

      it 'returns false otherwise' do
        build_model.state = BuildModel::FAILED_STATE
        expect(build_model.staged?).to be(false)
      end
    end

    describe '#failed?' do
      it 'returns true when state is FAILED' do
        build_model.state = BuildModel::FAILED_STATE
        expect(build_model.failed?).to be(true)
      end

      it 'returns false otherwise' do
        build_model.state = BuildModel::STAGING_STATE
        expect(build_model.failed?).to be(false)
      end
    end

    describe '#staging?' do
      it 'returns true when state is STAGING' do
        build_model.state = BuildModel::STAGING_STATE
        expect(build_model.staging?).to be(true)
      end

      it 'returns false otherwise' do
        build_model.state = BuildModel::FAILED_STATE
        expect(build_model.staging?).to be(false)
      end
    end

    describe '#fail_to_stage!' do
      before { build_model.update(state: BuildModel::STAGING_STATE) }

      it 'sets the state to FAILED' do
        expect { build_model.fail_to_stage! }.to change(build_model, :state).to(BuildModel::FAILED_STATE)
      end

      context 'when the state is not in the FAILED state' do
        it 'creates an app usage event for STAGING_STOPPED' do
          expect do
            build_model.fail_to_stage!
          end.to change(AppUsageEvent, :count).by(1)

          event = AppUsageEvent.last
          expect(event).not_to be_nil
          expect(event.state).to eq('STAGING_STOPPED')
        end
      end

      context 'when the build is already in the FAILED state' do
        let(:previously_failed_build) { create(:build_model, package: package, state: BuildModel::FAILED_STATE) }

        it 'creates an app usage event for STAGING_STOPPED' do
          expect do
            previously_failed_build.fail_to_stage!
          end.not_to(change(AppUsageEvent, :count))

          event = AppUsageEvent.last
          expect(event).to be_nil
        end
      end

      context 'when a valid reason is specified' do
        BuildModel::STAGING_FAILED_REASONS.each do |reason|
          it 'sets the requested staging failed reason' do
            expect do
              build_model.fail_to_stage!(reason)
            end.to change(build_model, :error_id).to(reason)
          end
        end
      end

      context 'when an unexpected reason is specifed' do
        it 'uses the default, generic reason' do
          expect do
            build_model.fail_to_stage!('bogus')
          end.to change(build_model, :error_id).to('StagingError')
        end
      end

      context 'when a reason is not specified' do
        it 'uses the default, generic reason' do
          expect do
            build_model.fail_to_stage!
          end.to change(build_model, :error_id).to('StagingError')
        end
      end

      describe 'setting staging_failed_description' do
        it 'sets the staging_failed_description to the v2.yml description of the error type' do
          expect do
            build_model.fail_to_stage!('NoAppDetectedError')
          end.to change(build_model, :error_description).to('An app was not successfully detected by any available buildpack')
        end

        it 'provides a string for interpolation on errors that require it' do
          expect do
            build_model.fail_to_stage!('StagingError')
          end.to change(build_model, :error_description).to('Staging error: staging failed')
        end

        BuildModel::STAGING_FAILED_REASONS.each do |reason|
          it "successfully sets staging_failed_description for reason: #{reason}" do
            expect do
              build_model.fail_to_stage!(reason)
            end.not_to raise_error
          end
        end
      end
    end

    describe '#mark_as_staged' do
      before { build_model.update(state: BuildModel::STAGING_STATE) }

      it 'sets the sate to STAGED' do
        expect { build_model.mark_as_staged }.to change(build_model, :state).to(BuildModel::STAGED_STATE)
      end

      it 'creates an app usage event for STAGING_STOPPED' do
        expect do
          build_model.mark_as_staged
        end.to change(AppUsageEvent, :count).by(1)

        event = AppUsageEvent.last
        expect(event).not_to be_nil
        expect(event.state).to eq('STAGING_STOPPED')
      end
    end

    describe '#record_staging_stopped' do
      let!(:buildpack_lifecycle_data) do
        create(:buildpack_lifecycle_data_model, build: build_model,
                                                buildpacks: ['http://some-buildpack.com', 'http://another-buildpack.net'])
      end

      before do
        build_model.buildpack_lifecycle_data = buildpack_lifecycle_data
        build_model.save
        build_model.update(state: BuildModel::STAGING_STATE)
      end

      it 'creates an app usage event for STAGING_STOPPED' do
        expect do
          build_model.record_staging_stopped
        end.to change(AppUsageEvent, :count).by(1)

        event = AppUsageEvent.last
        expect(event).not_to be_nil
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

        expect(event.buildpack_guid).to be_nil
        expect(event.buildpack_name).to eq('http://some-buildpack.com')
      end

      describe 'metadata' do
        let!(:label) { create(:build_label_model, key_name: 'string', value: 'string2', resource_guid: build_model.guid) }
        let!(:annotation) { create(:build_annotation_model, key_name: 'string', value: 'string2', resource_guid: build_model.guid) }

        it 'can access its annotations and labels' do
          expect(label.resource_guid).to eq(build_model.guid)
          expect(annotation.resource_guid).to eq(build_model.guid)
        end

        it 'deletes metadata on destroy' do
          build_model.destroy
          expect(label).not_to exist
          expect(annotation).not_to exist
        end

        it 'deletes metadata on delete due to DELETE CASCADE foreign key' do
          expect do
            build_model.delete
          end.not_to raise_error
        end
      end
    end
  end
end
