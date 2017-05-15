require 'spec_helper'
require 'actions/build_create'
require 'isolation_segment_assign'
require 'isolation_segment_unassign'

module VCAP::CloudController
  RSpec.describe BuildCreate do
    subject(:action) do
      described_class.new(
        memory_limit_calculator: memory_limit_calculator,
        disk_limit_calculator:   disk_limit_calculator,
        environment_presenter:   environment_builder
      )
    end

    let(:memory_limit_calculator) { double(:memory_limit_calculator) }
    let(:disk_limit_calculator) { double(:disk_limit_calculator) }
    let(:environment_builder) { double(:environment_builder) }

    let(:staging_message) { BuildCreateMessage.create_from_http_request(request) }
    let(:request) do
      {
        lifecycle: {
          type: 'buildpack',
          data: lifecycle_data
        },
      }.deep_stringify_keys
    end
    let(:lifecycle) { BuildpackLifecycle.new(package, staging_message) }
    let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }

    let(:space) { Space.make }
    let(:org) { space.organization }
    let(:app) { AppModel.make(space: space) }

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

    let(:staging_memory_in_mb) { nil }
    let(:staging_disk_in_mb) { nil }
    let(:environment_variables) { 'random string' }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_app).and_return(stager)
      allow(stager).to receive(:stage)
      allow(memory_limit_calculator).to receive(:get_limit).with(staging_memory_in_mb, space, org).and_return(calculated_mem_limit)
      allow(disk_limit_calculator).to receive(:get_limit).with(staging_disk_in_mb).and_return(calculated_staging_disk_in_mb)
      allow(environment_builder).to receive(:build).and_return(environment_variables)
    end

    describe '#create_and_stage' do
      context 'creating a build and dependent droplet' do
        it 'creates a build' do
          build = nil

          expect {
            build = action.create_and_stage(package: package, lifecycle: lifecycle)
          }.to change { BuildModel.count }.by(1)

          expect(build.state).to eq(BuildModel::STAGING_STATE)
          expect(build.app_guid).to eq(app.guid)
          expect(build.package_guid).to eq(package.guid)
          expect(build.lifecycle_data.to_hash).to eq(lifecycle_data)
        end
      end

      describe 'creating a stage request' do
        it 'initiates a staging request' do
          build = action.create_and_stage(package: package, lifecycle: lifecycle)
          expect(stager).to have_received(:stage) do |staging_details|
            expect(staging_details.package).to eq(package)
            expect(staging_details.staging_guid).to eq(build.guid)
            expect(staging_details.staging_memory_in_mb).to eq(calculated_mem_limit)
            expect(staging_details.staging_disk_in_mb).to eq(calculated_staging_disk_in_mb)
            expect(staging_details.environment_variables).to eq(environment_variables)
            expect(staging_details.lifecycle).to eq(lifecycle)
            expect(staging_details.isolation_segment).to be_nil
          end
        end

        describe 'isolation segments' do
          let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
          let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
          let(:isolation_segment_model_2) { VCAP::CloudController::IsolationSegmentModel.make }
          let(:shared_isolation_segment) {
            VCAP::CloudController::IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
          }

          context 'when the org has a default' do
            context 'and the default is the shared isolation segments' do
              before do
                assigner.assign(shared_isolation_segment, [org])
              end

              it 'does not set an isolation segment' do
                action.create_and_stage(package: package, lifecycle: lifecycle)
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
                action.create_and_stage(package: package, lifecycle: lifecycle)
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
                    action.create_and_stage(package: package, lifecycle: lifecycle)
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
                    action.create_and_stage(package: package, lifecycle: lifecycle)
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
                  action.create_and_stage(package: package, lifecycle: lifecycle)
                  expect(stager).to have_received(:stage) do |staging_details|
                    expect(staging_details.isolation_segment).to eq(isolation_segment_model.name)
                  end
                end
              end
            end
          end
        end
      end

      context 'when staging is unsuccessful' do
        context 'when the package is not ready' do
          let(:package) { PackageModel.make(app: app, state: PackageModel::PENDING_STATE) }
          it 'raises an InvalidPackage exception' do
            expect {
              action.create_and_stage(package: package, lifecycle: lifecycle)
            }.to raise_error(BuildCreate::InvalidPackage, /not ready/)
          end
        end

        context 'when there is already a staging in progress for the app' do
          it 'raises a StagingInProgress exception' do
            BuildModel.make(state: BuildModel::STAGING_STATE, app: app)
            expect {
              action.create_and_stage(package: package, lifecycle: lifecycle)
            }.to raise_error(BuildCreate::StagingInProgress)
          end
        end
      end
    end
  end
end
