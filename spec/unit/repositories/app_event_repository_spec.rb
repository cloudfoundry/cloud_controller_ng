require 'spec_helper'

module VCAP::CloudController
  module Repositories
    RSpec.describe AppEventRepository do
      subject(:app_event_repository) { AppEventRepository.new }
      let(:user_audit_info) { UserAuditInfo.new(user_email:, user_name:, user_guid:) }
      let(:user_guid) { 'user guid' }
      let(:user_email) { 'user email' }
      let(:user_name) { 'user name' }

      describe '#record_app_update' do
        let(:attrs) do
          {
            'name' => 'old',
            'instances' => 1,
            'memory' => 84,
            'state' => 'STOPPED',
            'environment_json' => { 'foo' => 1 },
            'docker_credentials' => {
              'username' => 'user',
              'password' => 'secret'
            }
          }
        end

        let(:process) { ProcessModelFactory.make(instances: 2, memory: 99, space: space) }
        let(:space) { Space.make }

        it 'records the expected fields on the event and logs the event' do
          expected_request_field = {
            'name' => 'old',
            'instances' => 1,
            'memory' => 84,
            'state' => 'STOPPED',
            'environment_json' => '[PRIVATE DATA HIDDEN]',
            'docker_credentials' => '[PRIVATE DATA HIDDEN]'
          }

          expect(VCAP::AppLogEmitter).to receive(:emit).with(process.guid, "Updated app with guid #{process.guid} (#{expected_request_field})")

          event = app_event_repository.record_app_update(process, space, user_audit_info, attrs).reload

          expect(event.space).to eq space
          expect(event.type).to eq 'audit.app.update'
          expect(event.actee).to eq process.guid
          expect(event.actee_type).to eq 'app'
          expect(event.actee_name).to eq process.name
          expect(event.actor).to eq user_guid
          expect(event.actor_type).to eq 'user'
          expect(event.actor_name).to eq user_email
          expect(event.actor_username).to eq user_name

          expect(event.metadata.fetch('request')).to eq(expected_request_field)
          expect(event.metadata.key?('manifest_triggered')).to be(false)
        end

        context 'when the event is manifest triggered' do
          let(:manifest_triggered) { true }

          it 'tags the event for manifest triggered as true' do
            event = app_event_repository.record_app_update(process, space, user_audit_info, attrs, manifest_triggered:).reload

            expect(event.metadata.fetch('manifest_triggered')).to be(true)
          end
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
            'docker_image' => 'image',
            'docker_credentials' => {
              'username' => 'user',
              'password' => 'secret'
            }
          }
        end

        let(:process) { ProcessModelFactory.make(request_attrs) }

        it 'records the event fields and metadata' do
          event = app_event_repository.record_app_create(process, process.space, user_audit_info, request_attrs)
          event.reload
          expect(event.type).to eq('audit.app.create')
          expect(event.actee).to eq(process.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(process.name)
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          request = event.metadata.fetch('request')
          expect(request).to eq(
            'name' => 'new',
            'instances' => 1,
            'memory' => 84,
            'state' => 'STOPPED',
            'environment_json' => '[PRIVATE DATA HIDDEN]',
            'docker_image' => 'image',
            'docker_credentials' => '[PRIVATE DATA HIDDEN]'
          )
        end

        it 'logs the event' do
          expect(VCAP::AppLogEmitter).to receive(:emit).with(process.guid, "Created app with guid #{process.guid}")

          app_event_repository.record_app_create(process, process.space, user_audit_info, request_attrs)
        end
      end

      describe '#record_app_delete' do
        let(:space) { Space.make }
        let(:process) { ProcessModelFactory.make(space:) }

        it 'creates a new audit.app.delete-request event' do
          event = app_event_repository.record_app_delete_request(process, space, user_audit_info, false)
          event.reload
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.type).to eq('audit.app.delete-request')
          expect(event.actee).to eq(process.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(process.name)
          expect(event.actor_username).to eq user_name
          expect(event.metadata['request']['recursive']).to be(false)
        end

        it 'does not record metadata when recursive is not passed' do
          event = app_event_repository.record_app_delete_request(process, space, user_audit_info)
          event.reload
          expect(event.metadata).to be_empty
        end

        it 'logs the event' do
          expect(VCAP::AppLogEmitter).to receive(:emit).with(process.guid, "Deleted app with guid #{process.guid}")

          app_event_repository.record_app_delete_request(process, space, user_audit_info, false)
        end
      end

      describe '#record_app_map_droplet' do
        let(:space) { Space.make }
        let(:app) { AppModel.make(space:) }

        it 'creates a new audit.app.droplet.mapped event' do
          event = app_event_repository.record_app_map_droplet(app, space, user_audit_info, { a: 1 })
          event.reload
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.type).to eq('audit.app.droplet.mapped')
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(app.name)
          expect(event.metadata).to eq({ 'request' => { 'a' => 1 } })
        end
      end

      describe '#record_app_apply_manifest' do
        let(:space) { Space.make }
        let(:app) { AppModel.make(space:) }
        let(:metadata) { { 'applications' => [{ 'name' => 'blah', 'instances' => 2 }] }.to_yaml }

        it 'creates a new audit.app.apply_manifest event' do
          event = app_event_repository.record_app_apply_manifest(app, space, user_audit_info, metadata)
          event.reload
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.type).to eq('audit.app.apply_manifest')
          expect(event.actee).to eq(app.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(app.name)
          expect(event.metadata).to eq({ 'request' => { 'manifest' => metadata } })
        end
      end

      describe '#create_app_crash_event' do
        let(:exiting_process) { ProcessModelFactory.make }
        let(:exit_description) { 'X' * AppEventRepository::TRUNCATE_THRESHOLD * 2 }
        let(:droplet_exited_payload) do
          {
            'instance' => 'abc',
            'index' => '2',
            'cell_id' => 'some-cell',
            'exit_status' => '1',
            'exit_description' => exit_description,
            'reason' => 'evacuation',
            'unknown_key' => 'something'
          }
        end

        it 'creates a new app exit event' do
          event = app_event_repository.create_app_crash_event(exiting_process, droplet_exited_payload)
          expect(event.type).to eq('app.crash')
          expect(event.actor).to eq(exiting_process.guid)
          expect(event.actor_type).to eq('app')
          expect(event.actor_name).to eq(exiting_process.name)
          expect(event.actee).to eq(exiting_process.guid)
          expect(event.actee_type).to eq('app')
          expect(event.actee_name).to eq(exiting_process.name)
          expect(event.metadata['unknown_key']).to be_nil
          expect(event.metadata['instance']).to eq('abc')
          expect(event.metadata['cell_id']).to eq('some-cell')
          expect(event.metadata['index']).to eq('2')
          expect(event.metadata['exit_status']).to eq('1')
          expect(event.metadata['exit_description'].length).to eq(AppEventRepository::TRUNCATE_THRESHOLD)
          expect(event.metadata['exit_description']).to eq(exit_description.truncate(AppEventRepository::TRUNCATE_THRESHOLD, omission: ' (truncated)'))
          expect(event.metadata['reason']).to eq('evacuation')
        end

        it 'logs the event' do
          expect(VCAP::AppLogEmitter).to receive(:emit).with(exiting_process.guid, "App instance exited with guid #{exiting_process.guid} payload: #{droplet_exited_payload}")

          app_event_repository.create_app_crash_event(exiting_process, droplet_exited_payload)
        end
      end

      describe '#record_map_route' do
        let(:space) { Space.make }
        let(:app) { AppModel.make(space:) }
        let(:route) { Route.make }
        let(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'potato') }

        it 'creates a new app.map_route audit event' do
          event = app_event_repository.record_map_route(user_audit_info, route_mapping)
          expect(event.type).to eq('audit.app.map-route')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee_type).to eq('app')
          expect(event.actee).to eq(app.guid)
          expect(event.metadata[:route_guid]).to eq(route.guid)
          expect(event.metadata[:manifest_triggered]).to be_nil
        end

        context 'when the event is manifest triggered' do
          let(:manifest_triggered) { true }

          it 'tags the event for manifest triggered as true' do
            event = app_event_repository.record_map_route(user_audit_info, route_mapping, manifest_triggered:)

            expect(event.metadata[:manifest_triggered]).to be(true)
          end
        end

        context 'when there is no actor' do
          let(:user_guid) { nil }

          it 'creates a new app.map_route audit event with system as the actor' do
            event = app_event_repository.record_map_route(user_audit_info, route_mapping)
            expect(event.type).to eq('audit.app.map-route')
            expect(event.actor).to eq('system')
            expect(event.actor_type).to eq('system')
            expect(event.actor_name).to eq('system')
            expect(event.actee_type).to eq('app')
            expect(event.actee).to eq(app.guid)
            expect(event.metadata[:route_guid]).to eq(route.guid)
          end
        end

        context 'when given route mapping information' do
          let(:app) { AppModel.make(space: route.space) }

          context 'when the route mapping is unweighted' do
            let(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'potato') }

            it 'creates a new app.map_route audit event with appropriate metadata' do
              event = app_event_repository.record_map_route(user_audit_info, route_mapping)
              expect(event.metadata[:route_guid]).to eq(route.guid)
              expect(event.metadata[:route_mapping_guid]).to eq(route_mapping.guid)
              expect(event.metadata[:destination_guid]).to eq(route_mapping.guid)
              expect(event.metadata[:process_type]).to eq('potato')
              expect(event.metadata[:weight]).to be_nil
            end
          end

          context 'when the route mapping has a weight' do
            let(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'potato', weight: 100) }

            it 'creates a new app.map_route audit event with appropriate metadata' do
              event = app_event_repository.record_map_route(user_audit_info, route_mapping)
              expect(event.metadata[:route_guid]).to eq(route.guid)
              expect(event.metadata[:route_mapping_guid]).to eq(route_mapping.guid)
              expect(event.metadata[:destination_guid]).to eq(route_mapping.guid)
              expect(event.metadata[:process_type]).to eq('potato')
              expect(event.metadata[:weight]).to eq(100)
            end
          end

          context 'when the route mapping has no protocol' do
            let(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'potato') }

            it 'creates a new app.map_route audit event with appropriate metadata' do
              event = app_event_repository.record_map_route(user_audit_info, route_mapping)
              expect(event.metadata[:route_guid]).to eq(route.guid)
              expect(event.metadata[:route_mapping_guid]).to eq(route_mapping.guid)
              expect(event.metadata[:destination_guid]).to eq(route_mapping.guid)
              expect(event.metadata[:process_type]).to eq('potato')
              expect(event.metadata[:protocol]).to eq('http1')
            end
          end

          context 'when the route mapping has a protocol' do
            let(:route_mapping) { RouteMappingModel.make(route: route, app: app, process_type: 'potato', protocol: 'http2') }

            it 'creates a new app.map_route audit event with appropriate metadata' do
              event = app_event_repository.record_map_route(user_audit_info, route_mapping)
              expect(event.metadata[:route_guid]).to eq(route.guid)
              expect(event.metadata[:route_mapping_guid]).to eq(route_mapping.guid)
              expect(event.metadata[:destination_guid]).to eq(route_mapping.guid)
              expect(event.metadata[:process_type]).to eq('potato')
              expect(event.metadata[:protocol]).to eq('http2')
            end
          end
        end
      end

      describe '#record_unmap_route' do
        let(:space) { Space.make }
        let(:app) { AppModel.make(space:) }
        let(:route) { Route.make }
        let(:route_mapping) { RouteMappingModel.make(route: route, guid: 'twice_baked', app: app, process_type: 'potato', weight: 100) }

        it 'creates a new app.unmap_route audit event' do
          event = app_event_repository.record_unmap_route(user_audit_info, route_mapping)
          expect(event.type).to eq('audit.app.unmap-route')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee_type).to eq('app')
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee).to eq(app.guid)
          expect(event.metadata[:route_guid]).to eq(route.guid)
          expect(event.metadata[:route_mapping_guid]).to eq(route_mapping.guid)
          expect(event.metadata[:process_type]).to eq('potato')
          expect(event.metadata[:manifest_triggered]).to be_nil
        end

        context 'when the event is manifest triggered' do
          it 'includes manifest_triggered in the metadata' do
            event = app_event_repository.record_unmap_route(user_audit_info, route_mapping, manifest_triggered: true)

            expect(event.metadata[:route_guid]).to eq(route.guid)
            expect(event.metadata[:route_mapping_guid]).to eq('twice_baked')
            expect(event.metadata[:process_type]).to eq('potato')
            expect(event.metadata[:manifest_triggered]).to be(true)
          end
        end

        context 'when there is no actor' do
          let(:user_guid) { nil }

          it 'creates a new app.unmap_route audit event with system as the actor' do
            event = app_event_repository.record_unmap_route(user_audit_info, route_mapping)
            expect(event.type).to eq('audit.app.unmap-route')
            expect(event.actor).to eq('system')
            expect(event.actor_type).to eq('system')
            expect(event.actor_name).to eq('system')
            expect(event.actee_type).to eq('app')
            expect(event.actee).to eq(app.guid)
            expect(event.metadata[:route_guid]).to eq(route.guid)
            expect(event.metadata[:route_mapping_guid]).to eq('twice_baked')
            expect(event.metadata[:process_type]).to eq('potato')
          end
        end
      end

      describe '#record_restage' do
        let(:process) { ProcessModelFactory.make }

        it 'creates a new app.restage event' do
          event = app_event_repository.record_app_restage(process, user_audit_info)
          expect(event.type).to eq('audit.app.restage')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(process.guid)
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee_type).to eq('app')
        end
      end

      describe '#record_src_copy_bits' do
        let(:src_process) { ProcessModelFactory.make }
        let(:dest_process) { ProcessModelFactory.make }

        it 'creates a new app.copy_bits event for the source app' do
          event = app_event_repository.record_src_copy_bits(dest_process, src_process, user_audit_info)

          expect(event.type).to eq('audit.app.copy-bits')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(src_process.guid)
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee_type).to eq('app')
          expect(event.metadata[:destination_guid]).to eq(dest_process.guid)
        end
      end

      describe '#record_dest_copy_bits' do
        let(:src_process) { ProcessModelFactory.make }
        let(:dest_process) { ProcessModelFactory.make }

        it 'creates a new app.copy_bits event for the destination app' do
          event = app_event_repository.record_dest_copy_bits(dest_process, src_process, user_audit_info)

          expect(event.type).to eq('audit.app.copy-bits')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(dest_process.guid)
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee_type).to eq('app')
          expect(event.metadata[:source_guid]).to eq(src_process.guid)
        end
      end

      describe '#record_app_ssh_unauthorized' do
        let(:process) { ProcessModelFactory.make }
        let(:instance_index) { 3 }

        it 'creates a new app.ssh-unauthorized event for the app' do
          event = app_event_repository.record_app_ssh_unauthorized(process, user_audit_info, instance_index)

          expect(event.type).to eq('audit.app.ssh-unauthorized')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(process.guid)
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee_type).to eq('app')
          expect(event.metadata).to eq({ index: instance_index })
        end
      end

      describe '#record_app_ssh_authorized' do
        let(:process) { ProcessModelFactory.make }
        let(:instance_index) { 3 }

        it 'creates a new app.ssh-authorized event for the app' do
          event = app_event_repository.record_app_ssh_authorized(process, user_audit_info, instance_index)

          expect(event.type).to eq('audit.app.ssh-authorized')
          expect(event.actor).to eq(user_guid)
          expect(event.actor_type).to eq('user')
          expect(event.actee).to eq(process.guid)
          expect(event.actor_name).to eq(user_email)
          expect(event.actor_username).to eq(user_name)
          expect(event.actee_type).to eq('app')
          expect(event.metadata).to eq({ index: instance_index })
        end
      end

      context 'obfuscation' do
        let(:space) { Space.make }

        context 'v2' do
          let(:attrs) { { 'buildpack' => buildpack } }
          let(:process) { ProcessModelFactory.make(instances: 2, memory: 99, space: space) }

          context 'when the buildpack is not nil' do
            let(:buildpack) { 'schmython' }

            it 'calls out to UrlSecretObfuscator' do
              allow(CloudController::UrlSecretObfuscator).to receive(:obfuscate)
              app_event_repository.record_app_update(process, space, user_audit_info, attrs)
              expect(CloudController::UrlSecretObfuscator).to have_received(:obfuscate).exactly :once
            end
          end

          context 'when the buildpack is nil' do
            let(:buildpack) { nil }

            it 'does nothing' do
              event = app_event_repository.record_app_update(process, space, user_audit_info, attrs).reload

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
              app_event_repository.record_app_update(app, space, user_audit_info, attrs)
              expect(CloudController::UrlSecretObfuscator).to have_received(:obfuscate).exactly :once
            end
          end

          context 'when the buildpack is nil' do
            let(:buildpack) { nil }

            it 'does nothing' do
              event = app_event_repository.record_app_update(app, space, user_audit_info, attrs).reload

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
          let(:request_attrs) do
            {
              'name' => 'new',
              'space_guid' => 'space-guid',
              'environment_variables' => { 'super' => 'secret ' }
            }
          end

          it 'records the actee_type and metadata correctly' do
            event = app_event_repository.record_app_create(app, app.space, user_audit_info, request_attrs)
            event.reload

            expect(event.type).to eq('audit.app.create')
            expect(event.actee_type).to eq('app')
            request = event.metadata.fetch('request')
            expect(request).to eq(
              'name' => 'new',
              'space_guid' => 'space-guid',
              'environment_variables' => '[PRIVATE DATA HIDDEN]'
            )
          end
        end

        describe '#record_app_start' do
          let(:app) { AppModel.make }

          it 'creates a new audit.app.start event' do
            event = app_event_repository.record_app_start(app, user_audit_info)

            expect(event.type).to eq('audit.app.start')

            expect(event.actor).to eq(user_guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(user_email)
            expect(event.actor_username).to eq(user_name)

            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('app')

            expect(event.space).to eq(app.space)
            expect(event.space_guid).to eq(app.space.guid)
          end
        end

        describe '#record_app_stop' do
          let(:app) { AppModel.make }

          it 'creates a new audit.app.stop event' do
            event = app_event_repository.record_app_stop(app, user_audit_info)

            expect(event.type).to eq('audit.app.stop')

            expect(event.actor).to eq(user_guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(user_email)
            expect(event.actor_username).to eq(user_name)

            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('app')

            expect(event.space).to eq(app.space)
            expect(event.space_guid).to eq(app.space.guid)
          end
        end

        describe '#record_app_restart' do
          let(:app) { AppModel.make }

          it 'creates a new audit.app.restart event' do
            event = app_event_repository.record_app_restart(app, user_audit_info)

            expect(event.type).to eq('audit.app.restart')

            expect(event.actor).to eq(user_guid)
            expect(event.actor_type).to eq('user')
            expect(event.actor_name).to eq(user_email)
            expect(event.actor_username).to eq(user_name)

            expect(event.actee).to eq(app.guid)
            expect(event.actee_type).to eq('app')
            expect(event.actee_name).to eq app.name
            expect(event.metadata).to eq({})

            expect(event.space_guid).to eq(app.space.guid)
            expect(event.organization_guid).to eq(app.organization.guid)
          end
        end
      end
    end
  end
end
