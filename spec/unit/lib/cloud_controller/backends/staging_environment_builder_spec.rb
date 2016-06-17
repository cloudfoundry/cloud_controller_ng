require 'spec_helper'
require 'cloud_controller/backends/staging_environment_builder'

module VCAP::CloudController
  RSpec.describe StagingEnvironmentBuilder do
    let(:builder) { StagingEnvironmentBuilder.new }

    describe '#build' do
      let(:app) { AppModel.make(environment_variables: { 'APP_VAR' => 'is here' }) }
      let(:space) { app.space }
      let(:stack) { 'my-stack' }
      let(:memory_limit) { 12340 }
      let(:staging_disk_in_mb) { 32100 }
      let(:lifecycle) { instance_double(BuildpackLifecycle, staging_environment_variables: { 'CF_STACK' => stack }) }
      let(:service) { Service.make(label: 'elephantsql-n/a', provider: 'cool-provider') }
      let(:service_plan) { ServicePlan.make(service: service) }
      let(:service_instance) { ManagedServiceInstance.make(space: space, service_plan: service_plan, name: 'elephantsql-vip-uat', tags: ['excellent']) }
      let!(:service_binding) { ServiceBindingModel.make(app: app, service_instance: service_instance, syslog_drain_url: 'logs.go-here.com') }

      before do
        staging_group = EnvironmentVariableGroup.staging
        staging_group.environment_json = { 'another' => 'var', 'STAGING_ENV' => 'staging_value' }
        staging_group.save

        app.environment_variables = app.environment_variables.merge({ 'another' => 'override' })
        app.save
      end

      it 'records the environment variables used for staging' do
        environment_variables = builder.build(app, space, lifecycle, memory_limit, staging_disk_in_mb)

        expect(environment_variables['VCAP_SERVICES'][service.label.to_sym][0].to_hash).to have_key(:credentials)
        expect(environment_variables).to match({
              'another' => 'override',
              'APP_VAR' => 'is here',
              'STAGING_ENV' => 'staging_value',
              'CF_STACK' => stack,
              'MEMORY_LIMIT' => "#{memory_limit}m",
              'VCAP_SERVICES' => be_an_instance_of(Hash),
              'VCAP_APPLICATION' => {
                limits: {
                  mem: memory_limit,
                  disk: staging_disk_in_mb,
                  fds: 16384
                },
                application_id: app.guid,
                application_name: app.name,
                name: app.name,
                application_uris: [],
                uris: [],
                application_version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
                version: /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
                space_name: space.name,
                space_id: space.guid,
                users: nil
              }
            })
      end

      context 'when the app has a route associated with it' do
        it 'includes the uris as part of vcap_application' do
          route1 = Route.make(space: space)
          route2 = Route.make(space: space)
          RouteMappingModel.make(app: app, route: route1)
          RouteMappingModel.make(app: app, route: route2)

          environment_variables = builder.build(app, space, lifecycle, memory_limit, staging_disk_in_mb)
          expect(environment_variables['VCAP_APPLICATION'][:uris]).to match_array([route1.fqdn, route2.fqdn])
          expect(environment_variables['VCAP_APPLICATION'][:application_uris]).to match_array([route1.fqdn, route2.fqdn])
        end
      end

      describe 'file descriptor limits' do
        it 'defaults to 16384' do
          environment_variables = builder.build(app, space, lifecycle, memory_limit, staging_disk_in_mb)
          expect(environment_variables['VCAP_APPLICATION'][:limits][:fds]).to eq(16384)
        end

        context 'when the file descriptor limit is configured' do
          before do
            TestConfig.config[:instance_file_descriptor_limit] = 100
          end

          it 'uses the configured value' do
            environment_variables = builder.build(app, space, lifecycle, memory_limit, staging_disk_in_mb)
            expect(environment_variables['VCAP_APPLICATION'][:limits][:fds]).to eq(100)
          end
        end
      end

      it 'merges vars_from_message' do
        vars_from_message = { THEEKEEY: 'stuff', 'ZEEKEY' => 'yukyuk' }

        environment_variables = builder.build(app, space, lifecycle, memory_limit, staging_disk_in_mb, vars_from_message)

        expect(environment_variables['THEEKEEY']).to eq('stuff')
        expect(environment_variables['ZEEKEY']).to eq('yukyuk')
      end
    end
  end
end
