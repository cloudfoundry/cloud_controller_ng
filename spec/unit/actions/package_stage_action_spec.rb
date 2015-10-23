require 'spec_helper'
require 'actions/package_stage_action'
require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'messages/droplet_create_message'

module VCAP::CloudController
  describe PackageStageAction do
    describe '#stage' do
      let(:action) { PackageStageAction.new(memory_limit_calculator, disk_limit_calculator, environment_builder) }
      let(:memory_limit_calculator) { double(:memory_limit_calculator) }
      let(:disk_limit_calculator) { double(:disk_limit_calculator) }
      let(:environment_builder) { double(:environment_builder) }
      let(:calculated_mem_limit) { 32 }
      let(:calculated_disk_limit) { 64 }
      let(:environment_variables) { 'environment_variables' }
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app) { AppModel.make(space_guid: space.guid) }
      let(:package) { PackageModel.make(app_guid: app.guid, state: PackageModel::READY_STATE) }
      let(:buildpack) { Buildpack.make }
      let(:staging_message) { DropletCreateMessage.create_from_http_request(request) }
      let(:stack) { Stack.default.name }
      let(:memory_limit) { 12340 }
      let(:disk_limit) { 32100 }
      let(:buildpack_git_url) { 'anything' }
      let(:stagers) { double(:stagers) }
      let(:droplet) { DropletModel.make(app: app) }
      let(:stager) { instance_double(Diego::V3::Stager) }
      let(:lifecycle_data) { { stack: Stack.default.name,
                               buildpack: buildpack_git_url }
      }
      let(:request) do
        {
          lifecycle: {
            type: 'buildpack',
            data: lifecycle_data
          },
          memory_limit: memory_limit,
          disk_limit: disk_limit
        }.deep_stringify_keys
      end
      let(:buildpack_info) { BuildpackRequestValidator.new }

      before do
        buildpack_info.buildpack_record = buildpack
        allow(stagers).to receive(:stager_for_package).and_return(stager)
        allow(stager).to receive(:stage)
        allow(memory_limit_calculator).to receive(:get_limit).with(memory_limit, space, org).and_return(calculated_mem_limit)
        allow(disk_limit_calculator).to receive(:get_limit).with(disk_limit).and_return(calculated_disk_limit)
        allow(environment_builder).to receive(:build).and_return(environment_variables)
      end

      context 'creating a droplet' do
        it 'creates a droplet' do
          expect {
            droplet = action.stage(package, buildpack_info, staging_message, stagers)
            expect(droplet.state).to eq(DropletModel::PENDING_STATE)
            expect(droplet.lifecycle_data.to_hash).to eq(lifecycle_data)
            expect(droplet.package_guid).to eq(package.guid)
            expect(droplet.buildpack_guid).to eq(buildpack.guid)
            expect(droplet.app_guid).to eq(app.guid)
            expect(droplet.memory_limit).to eq(calculated_mem_limit)
            expect(droplet.disk_limit).to eq(calculated_disk_limit)
            expect(droplet.environment_variables).to eq(environment_variables)
            expect(droplet.stack_name).to eq(stack)
          }.to change { DropletModel.count }.by(1)
        end
      end

      context 'creating a stage request' do
        before do
          allow(DropletModel).to receive(:create).and_return(droplet)
        end

        it 'initiates a staging request' do
          action.stage(package, buildpack_info, staging_message, stagers)
          expect(stager).to have_received(:stage) do |staging_details|
            expect(staging_details.droplet).to eq(droplet)
            expect(staging_details.stack).to eq(stack)
            expect(staging_details.memory_limit).to eq(calculated_mem_limit)
            expect(staging_details.disk_limit).to eq(calculated_disk_limit)
            expect(staging_details.buildpack_info).to eq(buildpack_info)
            expect(staging_details.environment_variables).to eq(environment_variables)
          end
        end

        context 'when the user does not specify a stack' do
          let(:stack) { nil }

          it 'uses a default value for stack' do
            action.stage(package, buildpack_info, staging_message, stagers)

            expect(stager).to have_received(:stage) do |staging_details|
              expect(staging_details.droplet).to eq(droplet)
              expect(staging_details.stack).to eq(Stack.default.name)
              expect(staging_details.memory_limit).to eq(calculated_mem_limit)
              expect(staging_details.disk_limit).to eq(calculated_disk_limit)
              expect(staging_details.buildpack_info).to eq(buildpack_info)
              expect(staging_details.environment_variables).to eq(environment_variables)
            end
          end
        end
      end

      context 'when staging is unsuccessful' do
        context 'when the package is not type bits' do
          let(:package) { PackageModel.make(app: app, type: PackageModel::DOCKER_TYPE) }
          it 'raises an InvalidPackage exception' do
            expect {
              action.stage(package, buildpack_info, staging_message, stagers)
            }.to raise_error(PackageStageAction::InvalidPackage)
          end
        end

        context 'when the package is not ready' do
          let(:package) { PackageModel.make(app: app, state: PackageModel::PENDING_STATE) }
          it 'raises an InvalidPackage exception' do
            expect {
              action.stage(package, buildpack_info, staging_message, stagers)
            }.to raise_error(PackageStageAction::InvalidPackage)
          end
        end

        context 'when the buildpack is a url' do
          before do
            buildpack_info.buildpack_record = nil
            buildpack_info.buildpack_url = buildpack_git_url
          end

          it 'does not include the buildpack guid in the droplet and staging message' do
            droplet = action.stage(package, buildpack_info, staging_message, stagers)

            expect(droplet.buildpack_guid).to be_nil
            expect(stager).to have_received(:stage)
          end
        end

        describe 'disk_limit' do
          context 'when disk_limit_calculator raises StagingDiskCalculator::LimitExceeded' do
            before do
              allow(disk_limit_calculator).to receive(:get_limit).with(disk_limit).and_raise(StagingDiskCalculator::LimitExceeded)
            end

            it 'raises PackageStageAction::DiskLimitExceeded' do
              expect {
                action.stage(package, buildpack_info, staging_message, stagers)
              }.to raise_error(PackageStageAction::DiskLimitExceeded)
            end
          end
        end

        describe 'memory_limit' do
          context 'when memory_limit_calculator raises MemoryLimitCalculator::SpaceQuotaExceeded' do
            before do
              allow(memory_limit_calculator).to receive(:get_limit).with(memory_limit, space, org).and_raise(StagingMemoryCalculator::SpaceQuotaExceeded)
            end

            it 'raises PackageStageAction::SpaceQuotaExceeded' do
              expect {
                action.stage(package, buildpack_info, staging_message, stagers)
              }.to raise_error(PackageStageAction::SpaceQuotaExceeded)
            end
          end

          context 'when memory_limit_calculator raises MemoryLimitCalculator::OrgQuotaExceeded' do
            before do
              allow(memory_limit_calculator).to receive(:get_limit).with(memory_limit, space, org).and_raise(StagingMemoryCalculator::OrgQuotaExceeded)
            end

            it 'raises PackageStageAction::OrgQuotaExceeded' do
              expect {
                action.stage(package, buildpack_info, staging_message, stagers)
              }.to raise_error(PackageStageAction::OrgQuotaExceeded)
            end
          end
        end
      end
    end
  end
end
