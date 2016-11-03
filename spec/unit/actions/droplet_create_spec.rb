require 'spec_helper'
require 'actions/droplet_create'
require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'
require 'cloud_controller/backends/staging_environment_builder'
require 'messages/droplet_create_message'
require 'isolation_segment_assign'
require 'isolation_segment_unassign'

module VCAP::CloudController
  RSpec.describe DropletCreate do
    subject(:action) { described_class.new(memory_limit_calculator, disk_limit_calculator, environment_builder) }
    let(:user) { User.make }
    let(:user_email) { 'user@example.com' }

    let(:memory_limit_calculator) { double(:memory_limit_calculator) }
    let(:disk_limit_calculator) { double(:disk_limit_calculator) }
    let(:environment_builder) { double(:environment_builder) }

    let(:lifecycle) { BuildpackLifecycle.new(package, staging_message) }
    let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }
    let(:app) { AppModel.make }
    let(:space) { app.space }
    let(:org) { space.organization }

    let(:staging_message) { DropletCreateMessage.create_from_http_request(request) }

    let(:request) do
      {
        lifecycle:            {
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

    let(:stagers) { instance_double(Stagers) }
    let(:stager) { instance_double(Diego::Stager) }
    let(:calculated_mem_limit) { 32 }
    let(:calculated_staging_disk_in_mb) { 64 }

    let(:environment_variables) { 'environment_variables' }

    before do
      allow(CloudController::DependencyLocator.instance).to receive(:stagers).and_return(stagers)
      allow(stagers).to receive(:stager_for_app).and_return(stager)
      allow(stager).to receive(:stage)
      allow(memory_limit_calculator).to receive(:get_limit).with(staging_memory_in_mb, space, org).and_return(calculated_mem_limit)
      allow(disk_limit_calculator).to receive(:get_limit).with(staging_disk_in_mb).and_return(calculated_staging_disk_in_mb)
      allow(environment_builder).to receive(:build).and_return(environment_variables)
    end

    describe '#create_and_stage' do
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

        action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
      end

      context 'creating a droplet' do
        it 'creates a droplet' do
          droplet = nil

          expect {
            droplet = action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
          }.to change { DropletModel.count }.by(1)

          expect(droplet.state).to eq(DropletModel::STAGING_STATE)
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
          droplet = action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
          expect(stager).to have_received(:stage) do |staging_details|
            expect(staging_details.package).to eq(package)
            expect(staging_details.droplet).to eq(droplet)
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
          let(:shared_isolation_segment) { VCAP::CloudController::IsolationSegmentModel.shared_segment }

          context 'when the org has a default' do
            context 'and the default is the shared isolation segments' do
              before do
                assigner.assign(shared_isolation_segment, [org])
              end

              it 'does not set an isolation segment' do
                action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
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
                action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
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
                    action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
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
                    action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
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
                  action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
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
              action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
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
                action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
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
                action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
              }.to raise_error(DropletCreate::SpaceQuotaExceeded)
            end
          end

          context 'when memory_limit_calculator raises MemoryLimitCalculator::OrgQuotaExceeded' do
            before do
              allow(memory_limit_calculator).to receive(:get_limit).with(staging_memory_in_mb, space, org).and_raise(StagingMemoryCalculator::OrgQuotaExceeded)
            end

            it 'raises DropletCreate::OrgQuotaExceeded' do
              expect {
                action.create_and_stage(package: package, lifecycle: lifecycle, message: staging_message, user: user, user_email: user_email)
              }.to raise_error(DropletCreate::OrgQuotaExceeded)
            end
          end
        end
      end
    end

    describe '#create_and_stage_without_event' do
      it 'does not create an audit event' do
        expect(Repositories::DropletEventRepository).not_to receive(:record_create_by_staging)
        action.create_and_stage_without_event(package: package, lifecycle: lifecycle, message: staging_message)
      end
    end
  end
end
