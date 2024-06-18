require 'spec_helper'
require 'actions/build_create'
require 'isolation_segment_assign'
require 'isolation_segment_unassign'

module VCAP::CloudController
  RSpec.describe BuildCreate do
    subject(:action) do
      BuildCreate.new(
        user_audit_info: user_audit_info,
        memory_limit_calculator: memory_limit_calculator,
        disk_limit_calculator: disk_limit_calculator,
        log_rate_limit_calculator: log_rate_limit_calculator,
        environment_presenter: environment_builder
      )
    end

    let(:memory_limit_calculator) { double(:memory_limit_calculator) }
    let(:disk_limit_calculator) { double(:disk_limit_calculator) }
    let(:log_rate_limit_calculator) { double(:log_rate_limit_calculator) }
    let(:environment_builder) { double(:environment_builder) }
    let(:user_audit_info) { UserAuditInfo.new(user_email: 'charles@las.gym', user_guid: '1234', user_name: 'charles') }

    let(:staging_message) { BuildCreateMessage.new(request) }
    let(:request) do
      {
        staging_memory_in_mb: staging_memory_in_mb,
        staging_disk_in_mb: staging_disk_in_mb,
        staging_log_rate_limit_bytes_per_second: staging_log_rate_limit_bytes_per_second,
        lifecycle: request_lifecycle
      }.deep_stringify_keys
    end
    let(:request_lifecycle) do
      {
        type: 'buildpack',
        data: lifecycle_data
      }
    end
    let(:metadata) do
      {
        labels: {
          release: 'stable',
          'seriouseats.com/potato' => 'mashed'
        },
        annotations: {
          anno: 'tations'
        }
      }
    end
    let(:lifecycle) { BuildpackLifecycle.new(package, staging_message) }
    let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }

    let(:space) { Space.make }
    let(:org) { space.organization }
    let(:app) { AppModel.make(space:) }
    let!(:process) { ProcessModel.make(app: app, memory: 8192, disk_quota: 512, log_rate_limit: 7168) }

    let(:buildpack_git_url) { 'http://example.com/repo.git' }
    let(:stack) { Stack.default }
    let(:lifecycle_data) do
      {
        stack: stack.name,
        buildpacks: [buildpack_git_url]
      }
    end

    let(:stagers) { instance_double(Stagers) }
    let(:stager) { instance_double(Diego::Stager) }
    let(:calculated_mem_limit) { 32 }
    let(:calculated_staging_disk_in_mb) { 64 }
    let(:calculated_staging_log_rate_limit) { 96 }

    let(:staging_memory_in_mb) { 1024 }
    let(:staging_disk_in_mb) { 2048 }
    let(:staging_log_rate_limit_bytes_per_second) { 3072 }
    let(:environment_variables) { 'random string' }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_build).and_return(stager)
      allow(stager).to receive(:stage)
      allow(memory_limit_calculator).to receive(:get_limit).with(staging_memory_in_mb, space, org).and_return(calculated_mem_limit)
      allow(disk_limit_calculator).to receive(:get_limit).with(staging_disk_in_mb).and_return(calculated_staging_disk_in_mb)
      allow(log_rate_limit_calculator).to receive(:get_limit).with(staging_log_rate_limit_bytes_per_second, space, org).and_return(calculated_staging_log_rate_limit)
      allow(environment_builder).to receive(:build).and_return(environment_variables)
    end

    describe '#create_and_stage' do
      context 'creating a build' do
        it 'creates a build' do
          build = nil

          expect do
            build = action.create_and_stage(package:, lifecycle:, metadata:)
          end.to change(BuildModel, :count).by(1)

          expect(build.state).to eq(BuildModel::STAGING_STATE)
          expect(build.app_guid).to eq(app.guid)
          expect(build.package_guid).to eq(package.guid)
          expect(build.staging_memory_in_mb).to eq(calculated_mem_limit)
          expect(build.staging_disk_in_mb).to eq(calculated_staging_disk_in_mb)
          expect(build.staging_log_rate_limit).to eq(calculated_staging_log_rate_limit)
          expect(build.lifecycle_data.to_hash).to eq(lifecycle_data)
          expect(build.created_by_user_guid).to eq('1234')
          expect(build.created_by_user_name).to eq('charles')
          expect(build.created_by_user_email).to eq('charles@las.gym')
          expect(build).to have_labels(
            { prefix: nil, key_name: 'release', value: 'stable' },
            { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' }
          )
          expect(build).to have_annotations(
            { key_name: 'anno', value: 'tations' }
          )
        end

        it 'creates an app usage event for STAGING_STARTED' do
          build = nil
          expect do
            build = action.create_and_stage(package:, lifecycle:, metadata:)
          end.to change(AppUsageEvent, :count).by(1)

          event = AppUsageEvent.last
          expect(event).not_to be_nil
          expect(event.state).to eq('STAGING_STARTED')
          expect(event.previous_state).to eq('STAGING')
          expect(event.instance_count).to eq(1)
          expect(event.previous_instance_count).to eq(1)
          expect(event.memory_in_mb_per_instance).to eq(BuildModel::STAGING_MEMORY)
          expect(event.previous_memory_in_mb_per_instance).to eq(BuildModel::STAGING_MEMORY)

          expect(event.org_guid).to eq(build.app.space.organization.guid)
          expect(event.space_guid).to eq(build.app.space.guid)
          expect(event.parent_app_guid).to eq(build.app.guid)
          expect(event.parent_app_name).to eq(build.app.name)
          expect(event.package_guid).to eq(build.package_guid)
          expect(event.app_name).to eq('')
          expect(event.app_guid).to eq('')
          expect(event.package_state).to eq('READY')
          expect(event.previous_package_state).to eq('READY')

          expect(event.buildpack_guid).to be_nil
          expect(event.buildpack_name).to eq(buildpack_git_url)
        end

        it 'creates a build audit event' do
          build = action.create_and_stage(package:, lifecycle:, metadata:)
          event = Event.last
          expect(event.type).to eq('audit.app.build.create')
          expect(event.actor).to eq('1234')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq('charles@las.gym')
          expect(event.actor_username).to eq('charles')
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(app.name)
          expect(event.timestamp).to be
          expect(event.space_guid).to eq(app.space_guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)
          expect(event.metadata).to eq({
                                         'build_guid' => build.guid,
                                         'package_guid' => package.guid
                                       })
        end

        it 'does not create a droplet audit event' do
          expect do
            action.create_and_stage(package:, lifecycle:)
          end.not_to(change do
            Event.where(type: 'audit.app.droplet.create').count
          end)
        end
      end

      context 'creating a build for type cnb' do
        let(:request_lifecycle) do
          {
            type: 'cnb',
            data: lifecycle_data
          }
        end
        let(:lifecycle) { CNBLifecycle.new(package, staging_message) }

        it 'creates a build' do
          build = nil

          expect do
            build = action.create_and_stage(package:, lifecycle:, metadata:)
          end.to change(BuildModel, :count).by(1)

          expect(build.state).to eq(BuildModel::STAGING_STATE)
          expect(build.app_guid).to eq(app.guid)
          expect(build.package_guid).to eq(package.guid)
          expect(build.staging_memory_in_mb).to eq(calculated_mem_limit)
          expect(build.staging_disk_in_mb).to eq(calculated_staging_disk_in_mb)
          expect(build.staging_log_rate_limit).to eq(calculated_staging_log_rate_limit)
          expect(build.lifecycle_data.to_hash).to eq(lifecycle_data)
          expect(build.created_by_user_guid).to eq('1234')
          expect(build.created_by_user_name).to eq('charles')
          expect(build.created_by_user_email).to eq('charles@las.gym')
          expect(build).to have_labels(
            { prefix: nil, key_name: 'release', value: 'stable' },
            { prefix: 'seriouseats.com', key_name: 'potato', value: 'mashed' }
          )
          expect(build).to have_annotations(
            { key_name: 'anno', value: 'tations' }
          )
        end

        it 'creates an app usage event for STAGING_STARTED' do
          build = nil
          expect do
            build = action.create_and_stage(package:, lifecycle:, metadata:)
          end.to change(AppUsageEvent, :count).by(1)

          event = AppUsageEvent.last
          expect(event).not_to be_nil
          expect(event.state).to eq('STAGING_STARTED')
          expect(event.previous_state).to eq('STAGING')
          expect(event.instance_count).to eq(1)
          expect(event.previous_instance_count).to eq(1)
          expect(event.memory_in_mb_per_instance).to eq(BuildModel::STAGING_MEMORY)
          expect(event.previous_memory_in_mb_per_instance).to eq(BuildModel::STAGING_MEMORY)

          expect(event.org_guid).to eq(build.app.space.organization.guid)
          expect(event.space_guid).to eq(build.app.space.guid)
          expect(event.parent_app_guid).to eq(build.app.guid)
          expect(event.parent_app_name).to eq(build.app.name)
          expect(event.package_guid).to eq(build.package_guid)
          expect(event.app_name).to eq('')
          expect(event.app_guid).to eq('')
          expect(event.package_state).to eq('READY')
          expect(event.previous_package_state).to eq('READY')

          expect(event.buildpack_guid).to be_nil
          expect(event.buildpack_name).to eq(buildpack_git_url)
        end

        it 'creates a build audit event' do
          build = action.create_and_stage(package:, lifecycle:, metadata:)
          event = Event.last
          expect(event.type).to eq('audit.app.build.create')
          expect(event.actor).to eq('1234')
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq('charles@las.gym')
          expect(event.actor_username).to eq('charles')
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(app.name)
          expect(event.timestamp).to be
          expect(event.space_guid).to eq(app.space_guid)
          expect(event.organization_guid).to eq(app.space.organization.guid)
          expect(event.metadata).to eq({
                                         'build_guid' => build.guid,
                                         'package_guid' => package.guid
                                       })
        end

        it 'does not create a droplet audit event' do
          expect do
            action.create_and_stage(package:, lifecycle:)
          end.not_to(change do
            Event.where(type: 'audit.app.droplet.create').count
          end)
        end
      end

      describe 'creating a stage request' do
        it 'initiates a staging request' do
          build = action.create_and_stage(package:, lifecycle:)
          expect(stager).to have_received(:stage) do |staging_details|
            expect(staging_details.package).to eq(package)
            expect(staging_details.staging_guid).to eq(build.guid)
            expect(staging_details.staging_memory_in_mb).to eq(calculated_mem_limit)
            expect(staging_details.staging_disk_in_mb).to eq(calculated_staging_disk_in_mb)
            expect(staging_details.staging_log_rate_limit_bytes_per_second).to eq(calculated_staging_log_rate_limit)
            expect(staging_details.environment_variables).to eq(environment_variables)
            expect(staging_details.lifecycle).to eq(lifecycle)
            expect(staging_details.isolation_segment).to be_nil
            expect(build.labels.size).to eq(0)
            expect(build.annotations.size).to eq(0)
          end
        end

        context 'when staging memory is not specified in the message' do
          before do
            allow(memory_limit_calculator).to receive(:get_limit).with(process.memory, space, org).and_return(process.memory)
          end

          let(:staging_memory_in_mb) { nil }

          it 'uses the app web process memory for staging memory' do
            expect(memory_limit_calculator).to receive(:get_limit).with(process.memory, space, org)

            build = action.create_and_stage(package:, lifecycle:)
            expect(build.staging_memory_in_mb).to eq(process.memory)
          end
        end

        context 'when staging disk is not specified in the message' do
          let(:staging_disk_in_mb) { nil }

          before do
            allow(disk_limit_calculator).to receive(:get_limit).with(process.disk_quota).and_return(process.disk_quota)
          end

          it 'uses the app web process disk for staging disk' do
            expect(disk_limit_calculator).to receive(:get_limit).with(process.disk_quota)
            build = action.create_and_stage(package:, lifecycle:)
            expect(build.staging_disk_in_mb).to eq(process.disk_quota)
          end
        end

        context 'when staging log rate limit is not specified in the message' do
          before do
            allow(log_rate_limit_calculator).to receive(:get_limit).with(process.log_rate_limit, space, org).and_return(process.log_rate_limit)
          end

          let(:staging_log_rate_limit_bytes_per_second) { nil }

          it 'uses the app web process log rate limit for staging log rate limit' do
            expect(log_rate_limit_calculator).to receive(:get_limit).with(process.log_rate_limit, space, org)

            build = action.create_and_stage(package:, lifecycle:)
            expect(build.staging_log_rate_limit).to eq(process.log_rate_limit)
          end
        end

        describe 'isolation segments' do
          let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
          let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
          let(:isolation_segment_model_2) { VCAP::CloudController::IsolationSegmentModel.make }
          let(:shared_isolation_segment) do
            VCAP::CloudController::IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
          end

          context 'when the org has a default' do
            context 'and the default is the shared isolation segments' do
              before do
                assigner.assign(shared_isolation_segment, [org])
              end

              it 'does not set an isolation segment' do
                action.create_and_stage(package:, lifecycle:)
                expect(stager).to have_received(:stage) do |staging_details|
                  expect(staging_details.isolation_segment).to be_nil
                end
              end
            end

            context 'and the default is not the shared isolation segment' do
              before do
                assigner.assign(isolation_segment_model, [org])
                org.update(default_isolation_segment_model: isolation_segment_model)
              end

              it 'sets the isolation segment' do
                action.create_and_stage(package:, lifecycle:)
                expect(stager).to have_received(:stage) do |staging_details|
                  expect(staging_details.isolation_segment).to eq(isolation_segment_model.name)
                end
              end

              context 'and the space from that org has an isolation segment' do
                context 'and the isolation segment is the shared isolation segment' do
                  before do
                    assigner.assign(shared_isolation_segment, [org])
                    space.isolation_segment_model = shared_isolation_segment
                    space.save
                    space.reload
                  end

                  it 'does not set the isolation segment' do
                    action.create_and_stage(package:, lifecycle:)
                    expect(stager).to have_received(:stage) do |staging_details|
                      expect(staging_details.isolation_segment).to be_nil
                    end
                  end
                end

                context 'and the isolation segment is not the shared or the default' do
                  before do
                    assigner.assign(isolation_segment_model_2, [org])
                    space.isolation_segment_model = isolation_segment_model_2
                    space.save
                  end

                  it 'sets the IS from the space' do
                    action.create_and_stage(package:, lifecycle:)
                    expect(stager).to have_received(:stage) do |staging_details|
                      expect(staging_details.isolation_segment).to eq(isolation_segment_model_2.name)
                    end
                  end
                end
              end
            end
          end

          context 'when the org does not have a default' do
            context 'and the space from that org has an isolation segment' do
              context 'and the isolation segment is not the shared isolation segment' do
                before do
                  assigner.assign(isolation_segment_model, [org])
                  space.isolation_segment_model = isolation_segment_model
                  space.save
                end

                it 'sets the isolation segment' do
                  action.create_and_stage(package:, lifecycle:)
                  expect(stager).to have_received(:stage) do |staging_details|
                    expect(staging_details.isolation_segment).to eq(isolation_segment_model.name)
                  end
                end
              end
            end
          end
        end
      end

      context 'when the package is not ready' do
        let(:package) { PackageModel.make(app: app, state: PackageModel::PENDING_STATE) }

        it 'raises an InvalidPackage exception' do
          expect do
            action.create_and_stage(package:, lifecycle:)
          end.to raise_error(BuildCreate::InvalidPackage, /not ready/)
        end
      end

      context 'when any buildpack is disabled' do
        let!(:disabled_buildpack) { Buildpack.make(enabled: false, name: 'disabled-buildpack') }
        let!(:enabled_buildpack) { Buildpack.make(name: 'enabled-buildpack') }
        let!(:lifecycle_data_model) do
          VCAP::CloudController::BuildpackLifecycleDataModel.make(
            app: app,
            buildpacks: [disabled_buildpack.name, enabled_buildpack.name, 'http://custom-buildpack.example'],
            stack: stack.name
          )
        end
        let(:lifecycle_data) do
          {
            stack: stack.name,
            buildpacks: [disabled_buildpack.name, enabled_buildpack.name, 'http://custom-buildpack.example']
          }
        end

        it 'raises an exception' do
          expect do
            action.create_and_stage(package:, lifecycle:)
          end.to raise_error(CloudController::Errors::ApiError, /'#{disabled_buildpack.name}' are disabled/)
        end
      end

      context 'when there is already a staging in progress for the app' do
        it 'raises a StagingInProgress exception' do
          BuildModel.make(state: BuildModel::STAGING_STATE, app: app)
          expect do
            action.create_and_stage(package:, lifecycle:)
          end.to raise_error(BuildCreate::StagingInProgress)
        end
      end

      context 'when the org quota is exceeded' do
        before do
          allow(log_rate_limit_calculator).to receive(:get_limit).and_raise(QuotaValidatingStagingLogRateLimitCalculator::OrgQuotaExceeded, 'some-message')
        end

        it 'raises a LogRateLimitOrgQuotaExceeded error' do
          expect do
            action.create_and_stage(package:, lifecycle:, metadata:)
          end.to raise_error(::VCAP::CloudController::BuildCreate::LogRateLimitOrgQuotaExceeded, 'some-message')
        end
      end

      context 'when the space quota is exceeded' do
        before do
          allow(log_rate_limit_calculator).to receive(:get_limit).and_raise(QuotaValidatingStagingLogRateLimitCalculator::SpaceQuotaExceeded, 'some-message')
        end

        it 'raises a LogRateLimitSpaceQuotaExceeded error' do
          expect do
            action.create_and_stage(package:, lifecycle:, metadata:)
          end.to raise_error(::VCAP::CloudController::BuildCreate::LogRateLimitSpaceQuotaExceeded, 'some-message')
        end
      end

      describe 'using custom buildpacks' do
        let!(:app) { AppModel.make(space:) }

        context 'when custom buildpacks are disabled' do
          before { TestConfig.override(disable_custom_buildpacks: true) }

          context 'when the custom buildpack is inherited from the app' do
            let(:request_lifecycle) do
              {}
            end

            before do
              app.update(buildpack_lifecycle_data: BuildpackLifecycleDataModel.create(
                buildpacks: ['http://example.com/repo.git'],
                stack: Stack.make.name
              ))
            end

            it 'raises an exception' do
              expect do
                action.create_and_stage(package:, lifecycle:)
              end.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
            end

            it 'does not create any DB records' do
              expect do
                action.create_and_stage(package:, lifecycle:)
              rescue StandardError
                nil
              end.not_to(change { [BuildModel.count, BuildpackLifecycleDataModel.count, AppUsageEvent.count, Event.count] })
            end
          end

          context 'when the custom buildpack is set on the build' do
            let(:lifecycle_data) do
              {
                stack: stack.name,
                buildpacks: ['http://example.com/repo.git']
              }
            end

            it 'raises an exception' do
              expect do
                action.create_and_stage(package:, lifecycle:)
              end.to raise_error(CloudController::Errors::ApiError, /Custom buildpacks are disabled/)
            end

            it 'does not create any DB records' do
              expect do
                action.create_and_stage(package:, lifecycle:)
              rescue StandardError
                nil
              end.not_to(change { [BuildModel.count, BuildpackLifecycleDataModel.count, AppUsageEvent.count, Event.count] })
            end
          end
        end

        context 'when custom buildpacks are enabled' do
          context 'when the custom buildpack is inherited from the app' do
            let!(:app_lifecycle_data_model) do
              BuildpackLifecycleDataModel.make(
                buildpacks: ['http://example.com/repo.git'],
                app: app
              )
            end

            let(:lifecycle_data) do
              {
                stack: stack.name,
                buildpacks: nil
              }
            end

            it 'successfully creates a build' do
              expect do
                action.create_and_stage(package:, lifecycle:)
              end.to change(BuildModel, :count).by(1)
            end
          end

          context 'when the custom buildpack is set on the build' do
            let(:lifecycle_data) do
              {
                stack: stack.name,
                buildpacks: ['http://example.com/repo.git']
              }
            end

            it 'successfully creates a build' do
              expect do
                action.create_and_stage(package:, lifecycle:)
              end.to change(BuildModel, :count).by(1)
            end
          end
        end
      end
    end
  end
end
