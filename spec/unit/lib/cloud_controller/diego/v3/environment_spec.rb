require 'spec_helper'
require 'cloud_controller/diego/v3/environment'

module VCAP::CloudController::Diego
  module V3
    describe Environment do
      let(:app_env_vars) { { 'ENV_VAR_2' => 'jeff' } }
      let(:app) { VCAP::CloudController::AppModel.make(environment_variables: app_env_vars, name: 'utako') }
      let(:space) { app.space }
      let(:memory_limit) { 128 }
      let(:disk_limit) { 512 }
      let(:expected_vcap_application) do
        {
          'limits'           => {
            'mem'  => memory_limit,
            'disk' => disk_limit,
            'fds'  => TestConfig.config[:instance_file_descriptor_limit] || 16384,
          },
          'application_id'   => app.guid,
          'application_version'   => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
          'application_name' => app.name,
          'application_uris' => [],
          'version'   => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
          'name'             => app.name,
          'space_name'       => space.name,
          'space_id'         => space.guid,
          'uris' => [],
          'users'            => nil
        }
      end

      describe '#build' do
        before do
          TestConfig.config[:instance_file_descriptor_limit] = 100
          TestConfig.config[:default_app_memory] = memory_limit
          TestConfig.config[:default_app_disk_in_mb] = disk_limit
        end

        it 'returns the correct environment hash for a v3 app' do
          constructed_envs = V3::Environment.new(app, space).build

          expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
          expect(constructed_envs).to include({ 'VCAP_SERVICES' => {} })
          expect(constructed_envs).to include({ 'MEMORY_LIMIT' => memory_limit })
          expect(constructed_envs).to include({ 'ENV_VAR_2' => 'jeff' })
        end

        context 'when running environment variable group is present' do
          running_envs = { 'ENV_VAR_2' => 'lily', 'PUPPIES' => 'frolicking' }

          it 'merges the app envs over the running env vars' do
            constructed_envs = V3::Environment.new(app, space, running_envs).build

            expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
            expect(constructed_envs).to include({ 'VCAP_SERVICES' => {} })
            expect(constructed_envs).to include({ 'MEMORY_LIMIT' => memory_limit })
            expect(constructed_envs).to include({ 'ENV_VAR_2' => 'jeff' })
            expect(constructed_envs).to include({ 'PUPPIES' => 'frolicking' })
          end
        end

        context 'when additional environment variables are provided' do
          it 'is merged on top of the initial envs and app envs' do
            running_envs    = { 'SILLY' => 'lily', 'PUPPIES' => 'frolicking' }
            additional_envs = { 'ENV_VAR_2' => 'not jeff', 'NICE' => 'shirt' }

            constructed_envs = V3::Environment.new(app, space, running_envs).build(additional_envs)
            expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
            expect(constructed_envs).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
            expect(constructed_envs).to include({ 'VCAP_SERVICES' => {} })
            expect(constructed_envs).to include({ 'MEMORY_LIMIT' => memory_limit })
            expect(constructed_envs).to include({ 'ENV_VAR_2' => 'not jeff' })
            expect(constructed_envs).to include({ 'SILLY' => 'lily' })
            expect(constructed_envs).to include({ 'PUPPIES' => 'frolicking' })
            expect(constructed_envs).to include({ 'NICE' => 'shirt' })
          end
        end

        context 'when the app has a route associated with it' do
          let(:expected_vcap_application) do
            {
              'limits'           => {
                'mem'  => memory_limit,
                'disk' => disk_limit,
                'fds'  => TestConfig.config[:instance_file_descriptor_limit] || 16384,
              },
              'application_id'   => app.guid,
              'application_version' => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
              'application_name' => app.name,
              'application_uris'    => [route1.fqdn, route2.fqdn],
              'version' => /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/,
              'uris'                => [route1.fqdn, route2.fqdn],
              'name'             => app.name,
              'space_name'       => space.name,
              'space_id'         => space.guid,
              'users'            => nil
            }
          end
          let(:route1) { VCAP::CloudController::Route.make(space: space) }
          let(:route2) { VCAP::CloudController::Route.make(space: space) }

          before do
            add_route_to_app = VCAP::CloudController::AddRouteToApp.new(nil, nil)
            add_route_to_app.add(app, route1, nil)
            add_route_to_app.add(app, route2, nil)
          end

          it 'includes the uris as part of vcap application' do
            expect(V3::Environment.new(app, space).build).to include({ 'VCAP_APPLICATION' => expected_vcap_application })
          end
        end
      end

      describe '#hash_to_diego_env' do
        let(:hash) do
          {
            'SILLY' => 'lily',
            'PUPPIES' => 'frolicking',
            'NICE' => 'shirt'
          }
        end

        it 'returns a diego-friendly environment variable representation' do
          diego_env = V3::Environment.hash_to_diego_env(hash)

          expect(diego_env).to include({ 'name' => 'SILLY', 'value' => 'lily' })
          expect(diego_env).to include({ 'name' => 'PUPPIES', 'value' => 'frolicking' })
          expect(diego_env).to include({ 'name' => 'NICE', 'value' => 'shirt' })
        end
      end
    end
  end
end
