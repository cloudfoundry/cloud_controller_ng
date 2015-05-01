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
      let(:calculated_mem_limit) { 32 }
      let(:disk_limit_calculator) { double(:disk_limit_calculator) }
      let(:calculated_disk_limit) { 64 }
      let(:environment_builder) { double(:environment_builder) }
      let(:environment_builder_response) { 'environment_builder_response' }
      let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }
      let(:app)  { AppModel.make(space: space) }
      let(:space)  { Space.make }
      let(:org) { space.organization }
      let(:buildpack)  { Buildpack.make }
      let(:staging_message) { DropletCreateMessage.create_from_http_request(opts) }
      let(:stack) { 'trusty32' }
      let(:memory_limit) { 12340 }
      let(:disk_limit) { 32100 }
      let(:buildpack_git_url) { 'anything' }
      let(:stagers) { double(:stagers) }
      let(:stager) { double(:stager) }
      let(:opts) do
        {
          stack:             stack,
          memory_limit:      memory_limit,
          disk_limit:        disk_limit,
          buildpack_git_url: buildpack_git_url,
        }.stringify_keys
      end

      before do
        allow(stagers).to receive(:stager_for_package).with(package).and_return(stager)
        allow(stager).to receive(:stage_package)
        allow(memory_limit_calculator).to receive(:get_limit).with(memory_limit, space, org).and_return(calculated_mem_limit)
        allow(disk_limit_calculator).to receive(:get_limit).with(disk_limit).and_return(calculated_disk_limit)
        allow(environment_builder).to receive(:build).and_return(environment_builder_response)
      end

      it 'creates a droplet' do
        expect {
          droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)
          expect(droplet.state).to eq(DropletModel::PENDING_STATE)
          expect(droplet.package_guid).to eq(package.guid)
          expect(droplet.buildpack_git_url).to eq(staging_message.buildpack_git_url)
          expect(droplet.buildpack_guid).to eq(buildpack.guid)
          expect(droplet.app_guid).to eq(app.guid)
          expect(droplet.environment_variables).to eq(environment_builder_response)
        }.to change { DropletModel.count }.by(1)
      end

      it 'initiates a staging request' do
        droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)
        expect(stager).to have_received(:stage_package).with(droplet, stack, calculated_mem_limit, calculated_disk_limit, buildpack.key, buildpack_git_url)
      end

      it 'has a default value for stack' do
        expected_stack = Stack.default.name
        staging_message.stack = nil

        droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)

        expect(stager).to have_received(:stage_package).with(droplet, expected_stack, calculated_mem_limit, calculated_disk_limit, buildpack.key, buildpack_git_url)
      end

      context 'when the package is not type bits' do
        let(:package) { PackageModel.make(app: app, type: PackageModel::DOCKER_TYPE) }
        it 'raises an InvalidPackage exception' do
          expect {
            action.stage(package, app, space, org, buildpack, staging_message, stagers)
          }.to raise_error(PackageStageAction::InvalidPackage)
        end
      end

      context 'when the package is not ready' do
        let(:package) { PackageModel.make(app: app, state: PackageModel::PENDING_STATE) }
        it 'raises an InvalidPackage exception' do
          expect {
            action.stage(package, app, space, org, buildpack, staging_message, stagers)
          }.to raise_error(PackageStageAction::InvalidPackage)
        end
      end

      context 'when the buildpack is not provided' do
        let(:buildpack) { nil }

        it 'does not include the buildpack guid in the droplet and staging message' do
          droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)

          expect(droplet.buildpack_guid).to be_nil
          expect(stager).to have_received(:stage_package).with(droplet, stack, calculated_mem_limit, calculated_disk_limit, nil, buildpack_git_url)
        end
      end

      describe 'disk_limit' do
        context 'when disk_limit_calculator raises StagingDiskCalculator::LimitExceeded' do
          before do
            allow(disk_limit_calculator).to receive(:get_limit).with(disk_limit).and_raise(StagingDiskCalculator::LimitExceeded)
          end

          it 'raises PackageStageAction::DiskLimitExceeded' do
            expect {
              action.stage(package, app, space, org, buildpack, staging_message, stagers)
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
              action.stage(package, app, space, org, buildpack, staging_message, stagers)
            }.to raise_error(PackageStageAction::SpaceQuotaExceeded)
          end
        end

        context 'when memory_limit_calculator raises MemoryLimitCalculator::OrgQuotaExceeded' do
          before do
            allow(memory_limit_calculator).to receive(:get_limit).with(memory_limit, space, org).and_raise(StagingMemoryCalculator::OrgQuotaExceeded)
          end

          it 'raises PackageStageAction::OrgQuotaExceeded' do
            expect {
              action.stage(package, app, space, org, buildpack, staging_message, stagers)
            }.to raise_error(PackageStageAction::OrgQuotaExceeded)
          end
        end
      end
    end
  end
end
