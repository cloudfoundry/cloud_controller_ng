require 'spec_helper'
require 'cloud_controller/diego/v3/environment'

module VCAP::CloudController::Diego
  module V3
    RSpec.describe Environment do
      let(:app_env_vars) { { 'ENV_VAR_2' => 'jeff' } }
      let(:app) { VCAP::CloudController::AppModel.make(environment_variables: app_env_vars, name: 'utako') }
      let(:task) { VCAP::CloudController::TaskModel.make(name: 'my-task', command: 'echo foo', memory_in_mb: 1024) }
      let(:space) { app.space }
      let(:staging_disk_in_mb) { 512 }
      let(:service) { VCAP::CloudController::Service.make(label: 'elephantsql-n/a', provider: 'cool-provider') }
      let(:service_plan) { VCAP::CloudController::ServicePlan.make(service: service) }
      let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space, service_plan: service_plan, name: 'elephantsql-vip-uat', tags: ['excellent']) }
      let!(:service_binding) { VCAP::CloudController::ServiceBindingModel.make(app: app, service_instance: service_instance, syslog_drain_url: 'logs.go-here.com') }

      let(:expected_vcap_application) do
        {
          limits: {
            mem: task.memory_in_mb,
            disk: staging_disk_in_mb,
            fds: TestConfig.config[:instance_file_descriptor_limit] || 16384,
          },
          application_id: app.guid,
          application_version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
          application_name: app.name,
          application_uris: [],
          version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
          name: app.name,
          space_name: space.name,
          space_id: space.guid,
          uris: [],
          users: nil
        }
      end

      describe '#build' do
        before do
          TestConfig.config[:instance_file_descriptor_limit] = 100
          TestConfig.config[:default_app_disk_in_mb] = staging_disk_in_mb
        end

        it 'returns the correct environment hash for a v3 app' do
          constructed_envs = V3::Environment.new(app, task, space).build

          expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
          expect(constructed_envs).to include({ 'VCAP_SERVICES' => be_an_instance_of(Hash) })
          expect(constructed_envs).to include({ 'MEMORY_LIMIT' => "#{task.memory_in_mb}m" })
          expect(constructed_envs).to include({ 'ENV_VAR_2' => 'jeff' })
        end

        context 'when running environment variable group is present' do
          running_envs = { 'ENV_VAR_2' => 'lily', 'PUPPIES' => 'frolicking' }

          it 'merges the app envs over the running env vars' do
            constructed_envs = V3::Environment.new(app, task, space, running_envs).build

            expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
            expect(constructed_envs).to include({ 'VCAP_SERVICES' => be_an_instance_of(Hash) })
            expect(constructed_envs).to include({ 'MEMORY_LIMIT' => "#{task.memory_in_mb}m" })
            expect(constructed_envs).to include({ 'ENV_VAR_2' => 'jeff' })
            expect(constructed_envs).to include({ 'PUPPIES' => 'frolicking' })
          end
        end

        context 'when additional environment variables are provided' do
          it 'is merged on top of the initial envs and app envs' do
            running_envs    = { 'SILLY' => 'lily', 'PUPPIES' => 'frolicking' }
            additional_envs = { 'ENV_VAR_2' => 'not jeff', 'NICE' => 'shirt' }

            constructed_envs = V3::Environment.new(app, task, space, running_envs).build(additional_envs)
            expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
            expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
            expect(constructed_envs).to include({ 'VCAP_SERVICES' => be_an_instance_of(Hash) })
            expect(constructed_envs).to include({ 'MEMORY_LIMIT' => "#{task.memory_in_mb}m" })
            expect(constructed_envs).to include({ 'ENV_VAR_2' => 'not jeff' })
            expect(constructed_envs).to include({ 'SILLY' => 'lily' })
            expect(constructed_envs).to include({ 'PUPPIES' => 'frolicking' })
            expect(constructed_envs).to include({ 'NICE' => 'shirt' })
          end
        end

        context 'when additional environment variables are nil' do
          it 'is merged on top of the initial envs and app envs' do
            running_envs = { 'SILLY' => 'lily', 'PUPPIES' => 'frolicking' }

            constructed_envs = V3::Environment.new(app, task, space, running_envs).build(nil)
            expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
            expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
            expect(constructed_envs).to include({ 'VCAP_SERVICES' => be_an_instance_of(Hash) })
            expect(constructed_envs).to include({ 'MEMORY_LIMIT' => "#{task.memory_in_mb}m" })
            expect(constructed_envs).to include({ 'ENV_VAR_2' => 'jeff' })
            expect(constructed_envs).to include({ 'SILLY' => 'lily' })
            expect(constructed_envs).to include({ 'PUPPIES' => 'frolicking' })
          end
        end

        context 'when the app has a route associated with it' do
          let(:expected_vcap_application) do
            {
              limits: {
                mem: task.memory_in_mb,
                disk: staging_disk_in_mb,
                fds: TestConfig.config[:instance_file_descriptor_limit] || 16384,
              },
              application_id: app.guid,
              application_version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
              application_name: app.name,
              application_uris: match_array([route1.fqdn, route2.fqdn]),
              version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
              uris: match_array([route1.fqdn, route2.fqdn]),
              name: app.name,
              space_name: space.name,
              space_id: space.guid,
              users: nil
            }
          end
          let(:route1) { VCAP::CloudController::Route.make(space: space) }
          let(:route2) { VCAP::CloudController::Route.make(space: space) }

          before do
            VCAP::CloudController::RouteMappingModel.make(app: app, route: route1)
            VCAP::CloudController::RouteMappingModel.make(app: app, route: route2)
          end

          it 'includes the uris as part of vcap application' do
            expect(V3::Environment.new(app, task, space).build).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
          end
        end
      end
    end
  end
end
