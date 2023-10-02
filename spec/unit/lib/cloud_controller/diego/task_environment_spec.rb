require 'spec_helper'
require 'cloud_controller/diego/task_environment'

module VCAP::CloudController::Diego
  RSpec.describe TaskEnvironment do
    let(:app_env_vars) { { 'ENV_VAR_2' => 'jeff' } }
    let(:app) { VCAP::CloudController::AppModel.make(environment_variables: app_env_vars, name: 'utako') }
    let(:task) { VCAP::CloudController::TaskModel.make(name: 'my-task', command: 'echo foo', memory_in_mb: 1024) }
    let(:space) { app.space }
    let(:staging_disk_in_mb) { 512 }
    let(:service) { VCAP::CloudController::Service.make(label: 'elephantsql-n/a') }
    let(:service_plan) { VCAP::CloudController::ServicePlan.make(service:) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan, name: 'elephantsql-vip-uat', tags: ['excellent']) }
    let!(:service_binding) { VCAP::CloudController::ServiceBinding.make(app: app, service_instance: service_instance, syslog_drain_url: 'logs.go-here.com') }

    let(:expected_vcap_application) do
      {
        cf_api: "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
        limits: {
          mem: task.memory_in_mb,
          disk: staging_disk_in_mb,
          fds: TestConfig.config[:instance_file_descriptor_limit] || 16_384
        },
        application_id: app.guid,
        application_version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
        application_name: app.name,
        application_uris: [],
        version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
        name: app.name,
        space_name: space.name,
        space_id: space.guid,
        organization_id: space.organization.guid,
        organization_name: space.organization.name,
        uris: [],
        users: nil
      }
    end

    describe '#build' do
      before do
        TestConfig.config[:instance_file_descriptor_limit] = 100
        TestConfig.config[:default_app_disk_in_mb]         = staging_disk_in_mb
      end

      it 'returns the correct environment hash for a v3 app' do
        constructed_envs = TaskEnvironment.new(app, task, space).build

        expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
        expect(constructed_envs).to include({ 'VCAP_SERVICES' => be_an_instance_of(Hash) })
        expect(constructed_envs).to include({ 'MEMORY_LIMIT' => "#{task.memory_in_mb}m" })
        expect(constructed_envs).to include({ 'ENV_VAR_2' => 'jeff' })
      end

      context 'when running environment variable group is present' do
        running_envs = { 'ENV_VAR_2' => 'lily', 'PUPPIES' => 'frolicking' }

        it 'merges the app envs over the running env vars' do
          constructed_envs = TaskEnvironment.new(app, task, space, running_envs).build

          expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
          expect(constructed_envs).to include({ 'VCAP_SERVICES' => be_an_instance_of(Hash) })
          expect(constructed_envs).to include({ 'MEMORY_LIMIT' => "#{task.memory_in_mb}m" })
          expect(constructed_envs).to include({ 'ENV_VAR_2' => 'jeff' })
          expect(constructed_envs).to include({ 'PUPPIES' => 'frolicking' })
        end
      end

      it 'uses environment variables from initial envs and app envs' do
        running_envs = { 'SILLY' => 'lily', 'PUPPIES' => 'frolicking' }

        constructed_envs = TaskEnvironment.new(app, task, space, running_envs).build
        expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
        expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
        expect(constructed_envs).to include({ 'VCAP_SERVICES' => be_an_instance_of(Hash) })
        expect(constructed_envs).to include({ 'MEMORY_LIMIT' => "#{task.memory_in_mb}m" })
        expect(constructed_envs).to include({ 'ENV_VAR_2' => 'jeff' })
        expect(constructed_envs).to include({ 'SILLY' => 'lily' })
        expect(constructed_envs).to include({ 'PUPPIES' => 'frolicking' })
      end

      context 'when the task is for a buildpack app' do
        let(:app) { VCAP::CloudController::AppModel.make(:buildpack) }

        it 'sets the LANG environment variable' do
          constructed_envs = TaskEnvironment.new(app, task, space).build
          expect(constructed_envs).to include('LANG' => 'en_US.UTF-8')
        end
      end

      context 'when the task is for a docker app' do
        let(:app) { VCAP::CloudController::AppModel.make(:docker) }

        it 'does not set the LANG environment variable' do
          constructed_envs = TaskEnvironment.new(app, task, space).build
          expect(constructed_envs).not_to have_key('LANG')
        end
      end

      context 'when the app has a route associated with it' do
        let(:expected_vcap_application) do
          {
            cf_api: "#{TestConfig.config[:external_protocol]}://#{TestConfig.config[:external_domain]}",
            limits: {
              mem: task.memory_in_mb,
              disk: staging_disk_in_mb,
              fds: TestConfig.config[:instance_file_descriptor_limit] || 16_384
            },
            application_id: app.guid,
            application_version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
            application_name: app.name,
            application_uris: contain_exactly(route1.fqdn, route2.fqdn),
            version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
            uris: contain_exactly(route1.fqdn, route2.fqdn),
            name: app.name,
            space_name: space.name,
            space_id: space.guid,
            organization_id: space.organization.guid,
            organization_name: space.organization.name,
            users: nil
          }
        end
        let(:route1) { VCAP::CloudController::Route.make(space:) }
        let(:route2) { VCAP::CloudController::Route.make(space:) }

        before do
          VCAP::CloudController::RouteMappingModel.make(app: app, route: route1)
          VCAP::CloudController::RouteMappingModel.make(app: app, route: route2)
        end

        it 'includes the uris as part of vcap application' do
          expect(TaskEnvironment.new(app, task, space).build).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
        end
      end

      context 'when the app has a database_uri' do
        before do
          allow(app).to receive(:database_uri).and_return('fake-database-uri')
        end

        it 'includes DATABASE_URL' do
          constructed_envs = TaskEnvironment.new(app, task, space).build
          expect(constructed_envs).to include({ 'DATABASE_URL' => 'fake-database-uri' })
        end
      end

      context 'when the app does not have a database_uri' do
        let(:app_env_vars) { { 'DATABASE_URL' => 'cool-db' } }

        before do
          allow(app).to receive(:database_uri).and_return(nil)
        end

        it 'uses the DATABASE_URL from the apps environment variable' do
          constructed_envs = TaskEnvironment.new(app, task, space).build
          expect(constructed_envs).to include({ 'DATABASE_URL' => 'cool-db' })
        end
      end

      context 'when the app has a credhub url' do
        let(:expected_credhub_url) do
          "{\"credhub-uri\":\"#{TestConfig.config_instance.get(:credhub_api, :internal_url)}\"}"
        end

        before do
          TestConfig.override(credhub_api: { internal_url: 'http:credhub.capi.land:8844' })
        end

        context 'when the interpolation of service bindings is enabled' do
          before do
            TestConfig.override(credential_references: { interpolate_service_bindings: true })
          end

          it 'includes the credhub uri as part of the VCAP_PLATFORM_OPTIONS variable' do
            constructed_envs = TaskEnvironment.new(app, task, space).build
            expect(constructed_envs).to include('VCAP_PLATFORM_OPTIONS' => expected_credhub_url)
          end
        end

        context 'when the interpolation of service bindings is disabled' do
          before do
            TestConfig.override(credential_references: { interpolate_service_bindings: false })
          end

          it 'does not include the VCAP_PLATFORM_OPTIONS' do
            constructed_envs = TaskEnvironment.new(app, task, space).build
            expect(constructed_envs).not_to have_key('VCAP_PLATFORM_OPTIONS')
          end
        end
      end

      context 'when the app does not have a credhub url' do
        before do
          TestConfig.override(credhub_api: nil)
        end

        it 'does not include the VCAP_PLATFORM_OPTIONS' do
          constructed_envs = TaskEnvironment.new(app, task, space).build
          expect(constructed_envs).not_to have_key('VCAP_PLATFORM_OPTIONS')
        end
      end
    end
  end
end
