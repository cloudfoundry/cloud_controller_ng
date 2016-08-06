require 'spec_helper'

module VCAP::CloudController
  module Repositories
    RSpec.describe AppEventRepository do
      subject(:app_event_repository) do
        AppEventRepository.new
      end

      describe '#record_app_update' do
        let(:attrs) do
          {
            'name' => 'old',
            'instances' => 1,
            'memory' => 84,
            'state' => 'STOPPED',
            'environment_json' => { 'foo' => 1 },
            'docker_credentials_json' => {
            'docker_login_server' => 'server',
            'docker_user' => 'user',
            'docker_password' => 'password',
            'docker_email' => 'email'
          },
          }
        end

        let(:app) { AppFactory.make(instances: 2, memory: 99, space: space) }
        let(:space) { Space.make }
        let(:user) { User.make }
        let(:user_email) { 'user email' }

        it 'records the expected fields on the event and logs the evena' do
          expected_request_field = {
            'name' => 'old',
            'instances' => 1,
            'memory' => 84,
            'state' => 'STOPPED',
            'environment_json' => 'PRIVATE DATA HIDDEN',
            'docker_credentials_json' => 'PRIVATE DATA HIDDEN',
          }

          expect(Loggregator).to receive(:emit).with(app.guid, "Updated app with guid #{app.guid} (#{expected_request_field})")

          event = app_event_repository.record_app_update(app, space, user.guid, user_email, attrs).reload

          expect(event.space).to eq space
          expect(event.type).to eq 'audit.app.update'
          expect(event.actee).to eq app.guid
          expect(event.actee_type).to eq 'app'
          expect(event.actee_name).to eq app.name
          expect(event.actor).to eq user.guid
          expect(event.actor_type).to eq 'user'
          expect(event.actor_name).to eq user_email

          request = event.metadata.fetch('request')
          expect(request).to eq(expected_request_field)
        end
      end

      describe '#record_app_create' do
        let(:request_attrs) do
          {
            'name' => 'new',
            'instances' => 1,
            'memory' => 84,
            'state' => 'STOPPED',
            'environment_json' => { 'super' => 'secret ' },
            'docker_credentials_json' => {
            'docker_login_server' => 'server',
            'docker_user' => 'user',
            'docker_password' => 'password',
            'docker_email' => 'email'
          },
          }
        end

        let(:app) { AppFactory.make(request_attrs) }
        let(:user) { User.make }
        let(:user_email) { 'user email' }

        it 'records the event fields and metadata' do
          event = app_event_repository.record_app_create(app, app.space, user.guid, user_email, request_attrs)
          event.reload
          expect(event.type).to eq('audit.app.create')
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(app.name)
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          request = event.metadata.fetch('request')
          expect(request).to eq(
            'name' => 'new',
            'instances' => 1,
            'memory' => 84,
            'state' => 'STOPPED',
            'environment_json' => 'PRIVATE DATA HIDDEN',
            'docker_credentials_json' => 'PRIVATE DATA HIDDEN',
          )
        end

        it 'logs the event' do
          expect(Loggregator).to receive(:emit).with(app.guid, "Created app with guid #{app.guid}")

          app_event_repository.record_app_create(app, app.space, user.guid, user_email, request_attrs)
        end
      end

      describe '#record_app_delete' do
        let(:space) { Space.make }
        let(:app) { AppFactory.make(space: space) }
        let(:user) { User.make }
        let(:user_email) { 'user email' }

        it 'creates a new audit.app.delete-request event' do
          event = app_event_repository.record_app_delete_request(app, space, user.guid, user_email, false)
          event.reload
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.type).to eq('audit.app.delete-request')
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(app.name)
          expect(event.metadata['request']['recursive']).to eq(false)
        end

        it 'does not record metadata when recursive is not passed' do
          event = app_event_repository.record_app_delete_request(app, space, user.guid, user_email)
          event.reload
          expect(event.metadata).to be_empty
        end

        it 'logs the event' do
          expect(Loggregator).to receive(:emit).with(app.guid, "Deleted app with guid #{app.guid}")

          app_event_repository.record_app_delete_request(app, space, user.guid, user_email, false)
        end
      end

      describe '#record_app_map_droplet' do
        let(:space) { Space.make }
        let(:app) { AppModel.make(space: space) }
        let(:user) { User.make }
        let(:user_email) { 'user email' }

        it 'creates a new audit.app.droplet_mapped event' do
          event = app_event_repository.record_app_map_droplet(app, space, user.guid, user_email, { a: 1 })
          event.reload
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.type).to eq('audit.app.droplet_mapped')
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('v3-app')
          expect(event.actee_name).to eq(app.name)
          expect(event.metadata).to eq({ 'request' => { 'a' => 1 } })
        end
      end

      describe '#create_app_exit_event' do
        let(:exiting_app) { AppFactory.make }
        let(:droplet_exited_payload) {
          {
            'instance' => 'abc',
            'index' => '2',
            'exit_status' => '1',
            'exit_description' => 'shut down',
            'reason' => 'evacuation',
            'unknown_key' => 'something'
          }
        }

        it 'creates a new app exit event' do
          event = app_event_repository.create_app_exit_event(exiting_app, droplet_exited_payload)
          expect(event.type).to eq('app.crash')
          expect(event.actor).to eq(exiting_app.guid)
          expect(event.actor_type).to eq('app')
          expect(event.actor_name).to eq(exiting_app.name)
          expect(event.actee).to eq(exiting_app.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(exiting_app.name)
          expect(event.metadata['unknown_key']).to eq(nil)
          expect(event.metadata['instance']).to eq('abc')
          expect(event.metadata['index']).to eq('2')
          expect(event.metadata['exit_status']).to eq('1')
          expect(event.metadata['exit_description']).to eq('shut down')
          expect(event.metadata['reason']).to eq('evacuation')
        end

        it 'logs the event' do
          expect(Loggregator).to receive(:emit).with(exiting_app.guid, "App instance exited with guid #{exiting_app.guid} payload: #{droplet_exited_payload}")

          app_event_repository.create_app_exit_event(exiting_app, droplet_exited_payload)
        end
      end

      describe '#record_map_route' do
        let(:app) { AppFactory.make }
        let(:route) { Route.make }

        context 'and the actor exists' do
          let(:user) { User.make }
          let(:user_email) { 'foo@example.com' }

          it 'creates a new app.map_route audit event' do
            event = app_event_repository.record_map_route(app, route, user.guid, user_email)
            expect(event.type).to eq('audit.app.map-route')
            expect(event.actor).to eq(user.guid)
            expect(event.actor_type).to eq('user')
            expect(event.actee_type).to eq('app')
            expect(event.actee).to eq(app.guid)
            expect(event.metadata[:route_guid]).to eq(route.guid)
          end
        end

        context 'and the actor is nil' do
          let(:user_email) { '' }

          it 'creates a new app.map_route audit event with system as the actor' do
            event = app_event_repository.record_map_route(app, route, nil, user_email)
            expect(event.type).to eq('audit.app.map-route')
            expect(event.actor).to eq('system')
            expect(event.actor_type).to eq('system')
            expect(event.actor_name).to eq('system')
            expect(event.actee_type).to eq('app')
            expect(event.actee).to eq(app.guid)
            expect(event.metadata[:route_guid]).to eq(route.guid)
          end
        end

        context 'and route mapping exists' do
          let(:app) { AppModel.make(space: route.space) }
          let(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'potato') }

          it 'creates a new app.map_route audit event with appropriate metadata' do
            event = app_event_repository.record_map_route(app, route, nil, nil, route_mapping: route_mapping)
            expect(event.metadata[:route_guid]).to eq(route.guid)
            expect(event.metadata[:route_mapping_guid]).to eq(route_mapping.guid)
            expect(event.metadata[:process_type]).to eq('potato')
          end
        end
      end

      describe '#record_unmap_route' do
        let(:app) { AppFactory.make }
        let(:route) { Route.make }

        context 'and the actor exists' do
          let(:user) { User.make }
          let(:user_email) { 'foo@example.com' }

          it 'creates a new app.unmap_route audit event' do
            event = app_event_repository.record_unmap_route(app, route, user.guid, user_email)
            expect(event.type).to eq('audit.app.unmap-route')
            expect(event.actor).to eq(user.guid)
            expect(event.actor_type).to eq('user')
            expect(event.actee_type).to eq('app')
            expect(event.actee).to eq(app.guid)
            expect(event.metadata[:route_guid]).to eq(route.guid)
          end
        end

        context 'and the actor is nil' do
          let(:user_email) { '' }

          it 'creates a new app.unmap_route audit event with system as the actor' do
            event = app_event_repository.record_unmap_route(app, route, nil, user_email)
            expect(event.type).to eq('audit.app.unmap-route')
            expect(event.actor).to eq('system')
            expect(event.actor_type).to eq('system')
            expect(event.actor_name).to eq('system')
            expect(event.actee_type).to eq('app')
            expect(event.actee).to eq(app.guid)
            expect(event.metadata[:route_guid]).to eq(route.guid)
          end
        end

        context 'and route mapping exists' do
          let(:app) { AppModel.make(space: route.space) }
          let(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'potato') }

          it 'creates a new app.map_route audit event with appropriate metadata' do
            event = app_event_repository.record_unmap_route(app, route, nil, nil, route_mapping: route_mapping)
            expect(event.metadata[:route_guid]).to eq(route.guid)
            expect(event.metadata[:route_mapping_guid]).to eq(route_mapping.guid)
            expect(event.metadata[:process_type]).to eq('potato')
          end
        end
      end

      describe '#record_restage' do
        let(:app) { AppFactory.make }
        let(:user) { User.make }
        let(:user_email) { 'user@example.com' }

        it 'creates a new app.restage event' do
          event = app_event_repository.record_app_restage(app, user.guid, user_email)
          expect(event.type).to eq('audit.app.restage')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(app.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.actee_type).to eq('app')
        end
      end

      describe '#record_src_copy_bits' do
        let(:src_app) { AppFactory.make }
        let(:dest_app) { AppFactory.make }
        let(:user) { User.make }
        let(:user_email) { 'user@example.com' }

        it 'creates a new app.copy_bits event for the source app' do
          event = app_event_repository.record_src_copy_bits(dest_app, src_app, user.guid, user_email)

          expect(event.type).to eq('audit.app.copy-bits')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(src_app.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.actee_type).to eq('app')
          expect(event.metadata[:destination_guid]).to eq(dest_app.guid)
        end
      end

      describe '#record_dest_copy_bits' do
        let(:src_app) { AppFactory.make }
        let(:dest_app) { AppFactory.make }
        let(:user) { User.make }
        let(:user_email) { 'user@example.com' }

        it 'creates a new app.copy_bits event for the destination app' do
          event = app_event_repository.record_dest_copy_bits(dest_app, src_app, user.guid, user_email)

          expect(event.type).to eq('audit.app.copy-bits')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(dest_app.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.actee_type).to eq('app')
          expect(event.metadata[:source_guid]).to eq(src_app.guid)
        end
      end

      describe '#record_app_ssh_unauthorized' do
        let(:app) { AppFactory.make }
        let(:user) { User.make }
        let(:user_email) { 'user@example.com' }
        let(:instance_index) { 3 }

        it 'creates a new app.ssh-unauthorized event for the app' do
          event = app_event_repository.record_app_ssh_unauthorized(app, user.guid, user_email, instance_index)

          expect(event.type).to eq('audit.app.ssh-unauthorized')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(app.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.actee_type).to eq('app')
          expect(event.metadata).to eq({ index: instance_index })
        end
      end

      describe '#record_app_ssh_authorized' do
        let(:app) { AppFactory.make }
        let(:user) { User.make }
        let(:user_email) { 'user@example.com' }
        let(:instance_index) { 3 }

        it 'creates a new app.ssh-authorized event for the app' do
          event = app_event_repository.record_app_ssh_authorized(app, user.guid, user_email, instance_index)

          expect(event.type).to eq('audit.app.ssh-authorized')
          expect(event.actor).to eq(user.guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(app.guid)
          expect(event.actor_name).to eq('user@example.com')
          expect(event.actee_type).to eq('app')
          expect(event.metadata).to eq({ index: instance_index })
        end
      end

      context 'obfuscation' do
        let(:space) { Space.make }
        let(:user) { User.make }
        let(:user_email) { 'user email' }

        context 'v2' do
          let(:attrs) { { 'buildpack' => buildpack } }
          let(:app) { AppFactory.make(instances: 2, memory: 99, space: space) }

          context 'when the buildpack is not nil' do
            let(:buildpack) { 'schmython' }

            it 'calls out to UrlSecretObfuscator' do
              allow(CloudController::UrlSecretObfuscator).to receive(:obfuscate)
              app_event_repository.record_app_update(app, space, user.guid, user_email, attrs)
              expect(CloudController::UrlSecretObfuscator).to have_received(:obfuscate).exactly :once
            end
          end

          context 'when the buildpack is nil' do
            let(:buildpack) { nil }

            it 'does nothing' do
              event = app_event_repository.record_app_update(app, space, user.guid, user_email, attrs).reload

              expect(event.metadata.fetch('request')).to eq('buildpack' => nil)
            end
          end
        end

        context 'v3' do
          let(:app) { AppModel.make }
          let(:buildpack) { 'schmython' }
          let(:attrs) do
            {
              'lifecycle' => {
                'type' => 'buildpack',
                'data' => { 'buildpack' => buildpack }
              }
            }
          end

          context 'when the buildpack is not nil' do
            it 'calls out to UrlSecretObfuscator' do
              allow(CloudController::UrlSecretObfuscator).to receive(:obfuscate)
              app_event_repository.record_app_update(app, space, user.guid, user_email, attrs)
              expect(CloudController::UrlSecretObfuscator).to have_received(:obfuscate).exactly :once
            end
          end

          context 'when the buildpack is nil' do
            let(:buildpack) { nil }

            it 'does nothing' do
              event = app_event_repository.record_app_update(app, space, user.guid, user_email, attrs).reload

              expected_request = {
                'lifecycle' => {
                  'type' => 'buildpack',
                  'data' => { 'buildpack' => nil }
                }
              }
              expect(event.metadata.fetch('request')).to eq expected_request
            end
          end
        end
      end

      context 'with a v3 app' do
        describe '#record_app_create' do
          let(:app) { AppModel.make(:buildpack) }
          let(:user) { User.make }
          let(:request_attrs) do
            {
              'name'             => 'new',
              'space_guid'       => 'space-guid',
              'environment_variables' => { 'super' => 'secret ' }
            }
          end

          it 'records the actee_type and metadata correctly' do
            event = app_event_repository.record_app_create(app, app.space, user, 'email', request_attrs)
            event.reload

            expect(event.type).to eq('audit.app.create')
            expect(event.actee_type).to eq('v3-app')
            request = event.metadata.fetch('request')
            expect(request).to eq(
              'name' => 'new',
              'space_guid' => 'space-guid',
              'environment_variables' => 'PRIVATE DATA HIDDEN',
            )
          end
        end

        describe '#record_app_start' do
          let(:app) { AppModel.make }
          let(:user) { User.make }
          let(:email) { 'user-email' }

          it 'creates a new audit.app.start event' do
            event = app_event_repository.record_app_start(app, user.guid, email)

            expect(event.type).to eq('audit.app.start')

            expect(event.actor).to eq(user.guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(email)

            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('v3-app')

            expect(event.space).to eq(app.space)
            expect(event.space_guid).to eq(app.space.guid)
          end
        end

        describe '#record_app_stop' do
          let(:app) { AppModel.make }
          let(:user) { User.make }
          let(:email) { 'user-email' }

          it 'creates a new audit.app.stop event' do
            event = app_event_repository.record_app_stop(app, user.guid, email)

            expect(event.type).to eq('audit.app.stop')

            expect(event.actor).to eq(user.guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(email)

            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('v3-app')

            expect(event.space).to eq(app.space)
            expect(event.space_guid).to eq(app.space.guid)
          end
        end
      end
    end
  end
end
