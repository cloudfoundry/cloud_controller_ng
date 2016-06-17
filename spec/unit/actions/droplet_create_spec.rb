require 'spec_helper'
require 'actions/droplet_create'
require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'messages/droplet_create_message'

module VCAP::CloudController
  RSpec.describe DropletCreate do
    describe '#create_and_stage' do
      let(:user) { User.make }
      let(:user_email) { 'user@example.com' }

      let(:action) { described_class.new(memory_limit_calculator, disk_limit_calculator, environment_builder, actor: user, actor_email: user_email) }

      let(:stagers) { double(:stagers) }
      let(:stager) { instance_double(Diego::V3::Stager) }
      let(:memory_limit_calculator) { double(:memory_limit_calculator) }
      let(:disk_limit_calculator) { double(:disk_limit_calculator) }
      let(:environment_builder) { double(:environment_builder) }
      let(:calculated_mem_limit) { 32 }
      let(:calculated_staging_disk_in_mb) { 64 }

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
          staging_memory_in_mb: staging_memory_in_mb,
          staging_disk_in_mb:   staging_disk_in_mb
        }.deep_stringify_keys
      end
      let(:staging_memory_in_mb) { 12340 }
      let(:staging_disk_in_mb) { 32100 }
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
        allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
        allow(stagers).to receive(:stager_for_package).and_return(stager)
        allow(stager).to receive(:stage)
        allow(memory_limit_calculator).to receive(:get_limit).with(staging_memory_in_mb, space, org).and_return(calculated_mem_limit)
        allow(disk_limit_calculator).to receive(:get_limit).with(staging_disk_in_mb).and_return(calculated_staging_disk_in_mb)
        allow(environment_builder).to receive(:build).and_return(environment_variables)
      end

      it 'creates an audit event' do
        expect(Repositories::DropletEventRepository).to receive(:record_create_by_staging).with(
          instance_of(DropletModel),
          user,
          user_email,
          staging_message.audit_hash,
          app.name,
          space.guid,
          org.guid
        )

        action.create_and_stage(package, lifecycle, staging_message)
      end

      context 'creating a droplet' do
        it 'creates a droplet' do
          droplet = nil

          expect {
            droplet = action.create_and_stage(package, lifecycle, staging_message)
          }.to change { DropletModel.count }.by(1)

          expect(droplet.state).to eq(DropletModel::PENDING_STATE)
          expect(droplet.lifecycle_data.to_hash).to eq(lifecycle_data)
          expect(droplet.package_guid).to eq(package.guid)
          expect(droplet.app_guid).to eq(app.guid)
          expect(droplet.staging_memory_in_mb).to eq(calculated_mem_limit)
          expect(droplet.staging_disk_in_mb).to eq(calculated_staging_disk_in_mb)
          expect(droplet.environment_variables).to eq(environment_variables)
          expect(droplet.lifecycle_data).to_not be_nil
        end
      end

      context 'creating a stage request' do
        it 'initiates a staging request' do
          droplet = action.create_and_stage(package, lifecycle, staging_message)
          expect(stager).to have_received(:stage) do |staging_details|
            expect(staging_details.droplet).to eq(droplet)
            expect(staging_details.staging_memory_in_mb).to eq(calculated_mem_limit)
            expect(staging_details.staging_disk_in_mb).to eq(calculated_staging_disk_in_mb)
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
              action.create_and_stage(package, lifecycle, staging_message)
            }.to raise_error(DropletCreate::InvalidPackage, /not ready/)
          end
        end

        describe 'staging_disk_in_mb' do
          context 'when disk_limit_calculator raises StagingDiskCalculator::LimitExceeded' do
            before do
              allow(disk_limit_calculator).to receive(:get_limit).with(staging_disk_in_mb).and_raise(StagingDiskCalculator::LimitExceeded)
            end

            it 'raises DropletCreate::DiskLimitExceeded' do
              expect {
                action.create_and_stage(package, lifecycle, staging_message)
              }.to raise_error(DropletCreate::DiskLimitExceeded)
            end
          end
        end

        describe 'staging_memory_in_mb' do
          context 'when memory_limit_calculator raises MemoryLimitCalculator::SpaceQuotaExceeded' do
            before do
              allow(memory_limit_calculator).to receive(:get_limit).with(staging_memory_in_mb, space, org).and_raise(StagingMemoryCalculator::SpaceQuotaExceeded)
            end

            it 'raises DropletCreate::SpaceQuotaExceeded' do
              expect {
                action.create_and_stage(package, lifecycle, staging_message)
              }.to raise_error(DropletCreate::SpaceQuotaExceeded)
            end
          end

          context 'when memory_limit_calculator raises MemoryLimitCalculator::OrgQuotaExceeded' do
            before do
              allow(memory_limit_calculator).to receive(:get_limit).with(staging_memory_in_mb, space, org).and_raise(StagingMemoryCalculator::OrgQuotaExceeded)
            end

            it 'raises DropletCreate::OrgQuotaExceeded' do
              expect {
                action.create_and_stage(package, lifecycle, staging_message)
              }.to raise_error(DropletCreate::OrgQuotaExceeded)
            end
          end
        end
      end
    end
  end
end
