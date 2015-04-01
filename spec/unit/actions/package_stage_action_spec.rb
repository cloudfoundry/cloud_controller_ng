require 'spec_helper'
require 'actions/package_stage_action'
require 'cloud_controller/backends/staging_memory_calculator'
require 'cloud_controller/backends/staging_disk_calculator'

module VCAP::CloudController
  describe PackageStageAction do
    describe '#stage' do
      let(:action) { PackageStageAction.new(memory_limit_calculator, disk_limit_calculator) }
      let(:memory_limit_calculator) { double(:memory_limit_calculator) }
      let(:calculated_mem_limit) { 32 }
      let(:disk_limit_calculator) { double(:disk_limit_calculator) }
      let(:calculated_disk_limit) { 64 }
      let(:package) { PackageModel.make(app: app, state: PackageModel::READY_STATE) }
      let(:app)  { AppModel.make(space: space, environment_variables: { 'APP_VAR' => 'is here' }) }
      let(:space)  { Space.make }
      let(:org) { space.organization }
      let(:buildpack)  { Buildpack.make }
      let(:staging_message) { StagingMessage.new(package.guid, opts) }
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
        EnvironmentVariableGroup.make(name: :staging, environment_json: { 'another' => 'var', 'STAGING_ENV' => 'staging_value' })
      end

      it 'creates a droplet' do
        expect {
          droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)
          expect(droplet.state).to eq(DropletModel::PENDING_STATE)
          expect(droplet.package_guid).to eq(package.guid)
          expect(droplet.buildpack_git_url).to eq(staging_message.buildpack_git_url)
          expect(droplet.buildpack_guid).to eq(buildpack.guid)
          expect(droplet.app_guid).to eq(app.guid)
        }.to change { DropletModel.count }.by(1)
      end

      it 'initiates a staging request' do
        droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)
        expect(stager).to have_received(:stage_package).with(droplet, stack, calculated_mem_limit, calculated_disk_limit, buildpack.key, buildpack_git_url)
      end

      it 'records the environment variables used for staging' do
        app.environment_variables = app.environment_variables.merge({ 'another' => 'override' })
        app.save
        droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)
        expect(droplet.environment_variables).to match({
          'another'     => 'override',
          'APP_VAR'     => 'is here',
          'STAGING_ENV' => 'staging_value',
          'CF_STACK' => stack,
          'VCAP_APPLICATION' => {
            'limits' => {
              'mem' => calculated_mem_limit,
              'disk' => calculated_disk_limit,
              'fds' => 16384
            },
            'application_name' => app.name,
            'name' => app.name,
            'application_uris' => [],
            'uris' => [],
            'application_version' => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
            'version' => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
            'space_name' => space.name,
            'space_id' => space.guid,
            'users' => nil
          }
        })
      end

      context 'when the app has a route associated with it' do
        it 'sends the uris of the app as part of vcap_application' do
          route1 = Route.make(space: space)
          route2 = Route.make(space: space)
          route_adder = AddRouteToApp.new(app)
          route_adder.add(route1)
          route_adder.add(route2)

          droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)
          expect(droplet.environment_variables['VCAP_APPLICATION']['uris']).to match([route1.fqdn, route2.fqdn])
          expect(droplet.environment_variables['VCAP_APPLICATION']['application_uris']).to match([route1.fqdn, route2.fqdn])
        end
      end

      context 'when instance_file_descriptor_limit is set' do
        it 'uses that value as the fds for staging' do
          TestConfig.config[:instance_file_descriptor_limit] = 100
          droplet = action.stage(package, app, space, org, buildpack, staging_message, stagers)
          expect(droplet.environment_variables['VCAP_APPLICATION']['limits']).to include({
            'fds' => TestConfig.config[:instance_file_descriptor_limit]
          })
        end
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
