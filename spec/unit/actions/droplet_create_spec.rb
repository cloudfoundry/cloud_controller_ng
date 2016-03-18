require 'spec_helper'
require 'actions/droplet_create'
require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'messages/droplet_create_message'

module VCAP::CloudController
  describe DropletCreate do
    describe '#create_and_stage' do
      let(:action) { described_class.new(memory_limit_calculator, disk_limit_calculator, environment_builder) }

      let(:stagers) { double(:stagers) }
      let(:stager) { instance_double(Diego::V3::Stager) }
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

      let(:staging_message) { DropletCreateMessage.create_from_http_request(request) }
      let(:request) do
        {
          lifecycle: {
            type: 'buildpack',
            data: lifecycle_data
          },
          memory_limit: memory_limit,
          disk_limit:   disk_limit
        }.deep_stringify_keys
      end
      let(:memory_limit) { 12340 }
      let(:disk_limit) { 32100 }
      let(:buildpack_git_url) { 'http://example.com/repo.git' }
      let(:stack) { Stack.default }
      let(:lifecycle_data) do
        {
          stack:     stack.name,
          buildpack: buildpack_git_url
        }
      end

      let(:lifecycle) do
        BuildpackLifecycle.new(package, staging_message)
      end

      before do
        allow(stagers).to receive(:stager_for_package).and_return(stager)
        allow(stager).to receive(:stage)
        allow(memory_limit_calculator).to receive(:get_limit).with(memory_limit, space, org).and_return(calculated_mem_limit)
        allow(disk_limit_calculator).to receive(:get_limit).with(disk_limit).and_return(calculated_disk_limit)
        allow(environment_builder).to receive(:build).and_return(environment_variables)
      end

      context 'creating a droplet' do
        it 'creates a droplet' do
          expect {
            droplet = action.create_and_stage(package, lifecycle, stagers)
            expect(droplet.state).to eq(DropletModel::PENDING_STATE)
            expect(droplet.lifecycle_data.to_hash).to eq(lifecycle_data)
            expect(droplet.package_guid).to eq(package.guid)
            expect(droplet.app_guid).to eq(app.guid)
            expect(droplet.memory_limit).to eq(calculated_mem_limit)
            expect(droplet.disk_limit).to eq(calculated_disk_limit)
            expect(droplet.environment_variables).to eq(environment_variables)
            expect(droplet.lifecycle_data).to_not be_nil
          }.to change { DropletModel.count }.by(1)
        end
      end

      context 'creating a stage request' do
        it 'initiates a staging request' do
          droplet = action.create_and_stage(package, lifecycle, stagers)
          expect(stager).to have_received(:stage) do |staging_details|
            expect(staging_details.droplet).to eq(droplet)
            expect(staging_details.memory_limit).to eq(calculated_mem_limit)
            expect(staging_details.disk_limit).to eq(calculated_disk_limit)
            expect(staging_details.environment_variables).to eq(environment_variables)
            expect(staging_details.lifecycle).to eq(lifecycle)
          end
        end
      end

      context 'when staging is unsuccessful' do
        context 'when the package is not ready' do
          let(:package) { PackageModel.make(app: app, state: PackageModel::PENDING_STATE) }
          it 'raises an InvalidPackage exception' do
            expect {
              action.create_and_stage(package, lifecycle, stagers)
            }.to raise_error(DropletCreate::InvalidPackage, /not ready/)
          end
        end

        describe 'disk_limit' do
          context 'when disk_limit_calculator raises StagingDiskCalculator::LimitExceeded' do
            before do
              allow(disk_limit_calculator).to receive(:get_limit).with(disk_limit).and_raise(StagingDiskCalculator::LimitExceeded)
            end

            it 'raises DropletCreate::DiskLimitExceeded' do
              expect {
                action.create_and_stage(package, lifecycle, stagers)
              }.to raise_error(DropletCreate::DiskLimitExceeded)
            end
          end
        end

        describe 'memory_limit' do
          context 'when memory_limit_calculator raises MemoryLimitCalculator::SpaceQuotaExceeded' do
            before do
              allow(memory_limit_calculator).to receive(:get_limit).with(memory_limit, space, org).and_raise(StagingMemoryCalculator::SpaceQuotaExceeded)
            end

            it 'raises DropletCreate::SpaceQuotaExceeded' do
              expect {
                action.create_and_stage(package, lifecycle, stagers)
              }.to raise_error(DropletCreate::SpaceQuotaExceeded)
            end
          end

          context 'when memory_limit_calculator raises MemoryLimitCalculator::OrgQuotaExceeded' do
            before do
              allow(memory_limit_calculator).to receive(:get_limit).with(memory_limit, space, org).and_raise(StagingMemoryCalculator::OrgQuotaExceeded)
            end

            it 'raises DropletCreate::OrgQuotaExceeded' do
              expect {
                action.create_and_stage(package, lifecycle, stagers)
              }.to raise_error(DropletCreate::OrgQuotaExceeded)
            end
          end
        end
      end
    end
  end
end
