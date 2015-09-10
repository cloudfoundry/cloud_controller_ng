require 'spec_helper'
require 'cloud_controller/backends/staging_environment_builder'

module VCAP::CloudController
  describe StagingEnvironmentBuilder do
    let(:builder) { StagingEnvironmentBuilder.new }

    describe '#build' do
      let(:app) { AppModel.make(environment_variables: { 'APP_VAR' => 'is here' }) }
      let(:space) { app.space }
      let(:stack) { 'my-stack' }
      let(:memory_limit) { 12340 }
      let(:disk_limit) { 32100 }

      before do
        EnvironmentVariableGroup.make(name: :staging, environment_json: { 'another' => 'var', 'STAGING_ENV' => 'staging_value' })
        app.environment_variables = app.environment_variables.merge({ 'another' => 'override' })
        app.save
      end

      it 'records the environment variables used for staging' do
        environment_variables = builder.build(app, space, stack, memory_limit, disk_limit)

        expect(environment_variables).to match({
              'another'          => 'override',
              'APP_VAR'          => 'is here',
              'STAGING_ENV'      => 'staging_value',
              'CF_STACK'         => stack,
              'MEMORY_LIMIT'     => memory_limit,
              'VCAP_SERVICES'    => {},
              'VCAP_APPLICATION' => {
                'limits'              => {
                  'mem'  => memory_limit,
                  'disk' => disk_limit,
                  'fds'  => 16384
                },
                'application_id'      => app.guid,
                'application_name'    => app.name,
                'name'                => app.name,
                'application_uris'    => [],
                'uris'                => [],
                'application_version' => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
                'version'             => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
                'space_name'          => space.name,
                'space_id'            => space.guid,
                'users'               => nil
              }
            })
      end

      context 'when the app has a route associated with it' do
        it 'includes the uris as part of vcap_application' do
          route1 = Route.make(space: space)
          route2 = Route.make(space: space)
          add_route_to_app = AddRouteToApp.new(nil, nil)
          add_route_to_app.add(app, route1, nil)
          add_route_to_app.add(app, route2, nil)

          environment_variables = builder.build(app, space, stack, memory_limit, disk_limit)
          expect(environment_variables['VCAP_APPLICATION']['uris']).to match([route1.fqdn, route2.fqdn])
          expect(environment_variables['VCAP_APPLICATION']['application_uris']).to match([route1.fqdn, route2.fqdn])
        end
      end

      describe 'file descriptor limits' do
        it 'defaults to 16384' do
          environment_variables = builder.build(app, space, stack, memory_limit, disk_limit)
          expect(environment_variables['VCAP_APPLICATION']['limits']['fds']).to eq(16384)
        end

        context 'when the file descriptor limit is configured' do
          before do
            TestConfig.config[:instance_file_descriptor_limit] = 100
          end

          it 'uses the configured value' do
            environment_variables = builder.build(app, space, stack, memory_limit, disk_limit)
            expect(environment_variables['VCAP_APPLICATION']['limits']['fds']).to eq(100)
          end
        end
      end
    end
  end
end
