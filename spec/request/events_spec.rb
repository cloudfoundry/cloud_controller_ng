require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Events' do
  describe 'GET /v3/audit_events' do
    let(:user) { make_user }
    let(:admin_header) { admin_headers_for(user) }
    let(:user_audit_info) {
      VCAP::CloudController::UserAuditInfo.new(user_guid: user.guid, user_email: 'user@example.com')
    }
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:app_model) { VCAP::CloudController::AppModel.make(space: space) }

    let!(:unscoped_event) {
      VCAP::CloudController::Repositories::OrphanedBlobEventRepository.record_delete('dir', 'key')
    }
    let!(:org_scoped_event) {
      VCAP::CloudController::Repositories::OrganizationEventRepository.new.record_organization_create(
        org,
        user_audit_info,
        { key: 'val' }
      )
    }
    let!(:space_scoped_event) {
      VCAP::CloudController::Repositories::AppEventRepository.new.record_app_restart(
        app_model,
        user_audit_info,
      )
    }

    let(:unscoped_event_json) do
      {
        guid: unscoped_event.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'blob.remove_orphan',
        actor: {
          guid: 'system',
          type: 'system',
          name: 'system'
        },
        target: {
          guid: 'dir/key',
          type: 'blob',
          name: ''
        },
        data: {},
        space: nil,
        organization: nil,
        links: {
          self: {
            href: "#{link_prefix}/v3/audit_events/#{unscoped_event.guid}"
          }
        }
      }
    end

    let(:org_scoped_event_json) do
      {
        guid: org_scoped_event.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'audit.organization.create',
        actor: {
          guid: user_audit_info.user_guid,
          type: 'user',
          name: user_audit_info.user_email
        },
        target: {
          guid: org.guid,
          type: 'organization',
          name: org.name
        },
        data: {
          request: {
            key: 'val'
          }
        },
        space: nil,
        organization: {
          guid: org.guid
        },
        links: {
          self: {
            href: "#{link_prefix}/v3/audit_events/#{org_scoped_event.guid}"
          }
        }
      }
    end

    let(:space_scoped_event_json) do
      {
        guid: space_scoped_event.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'audit.app.restart',
        actor: {
          guid: user_audit_info.user_guid,
          type: 'user',
          name: user_audit_info.user_email
        },
        target: {
          guid: app_model.guid,
          type: 'app',
          name: app_model.name
        },
        data: {},
        space: {
          guid: space.guid
        },
        organization: {
          guid: org.guid
        },
        links: {
          self: {
            href: "#{link_prefix}/v3/audit_events/#{space_scoped_event.guid}"
          }
        }
      }
    end

    context 'without filters' do
      let(:api_call) { lambda { |user_headers| get '/v3/audit_events', nil, user_headers } }

      let(:expected_codes_and_responses) do
        h = Hash.new(code: 200, response_objects: [])

        h['admin'] = { code: 200, response_objects: [unscoped_event_json, org_scoped_event_json, space_scoped_event_json] }
        h['admin_read_only'] = { code: 200, response_objects: [unscoped_event_json, org_scoped_event_json, space_scoped_event_json] }
        h['global_auditor'] = { code: 200, response_objects: [unscoped_event_json, org_scoped_event_json, space_scoped_event_json] }

        h['space_auditor'] = { code: 200, response_objects: [space_scoped_event_json] }
        h['space_developer'] = { code: 200, response_objects: [space_scoped_event_json] }

        h['org_auditor'] = { code: 200, response_objects: [org_scoped_event_json, space_scoped_event_json] }

        h
      end

      it_behaves_like 'permissions for list endpoint', ALL_PERMISSIONS
    end

    context 'filtering by type' do
      it 'returns filtered events' do
        get '/v3/audit_events?types=audit.app.restart', nil, admin_header

        expect({
          resources: parsed_response['resources']
        }).to match_json_response({
          resources: [space_scoped_event_json]
        })
      end
    end

    context 'filtering by target_guid' do
      it 'returns filtered events' do
        get "/v3/audit_events?target_guids=#{app_model.guid}", nil, admin_header

        expect({
          resources: parsed_response['resources']
        }).to match_json_response({
          resources: [space_scoped_event_json]
        })
      end
    end

    context 'filtering by space_guid' do
      it 'returns filtered events' do
        get "/v3/audit_events?space_guids=#{space.guid}", nil, admin_header

        expect({
          resources: parsed_response['resources']
        }).to match_json_response({
          resources: [space_scoped_event_json]
        })
      end
    end

    context 'filtering by organization_guid' do
      it 'returns filtered events' do
        get "/v3/audit_events?organization_guids=#{org.guid}", nil, admin_header

        expect({
          resources: parsed_response['resources']
        }).to match_json_response({
          resources: [org_scoped_event_json, space_scoped_event_json]
        })
      end
    end
  end

  describe 'GET /v3/audit_events/:guid' do
    let(:user) { make_user }
    let(:admin_header) { admin_headers_for(user) }
    let(:space) { VCAP::CloudController::Space.make }
    let(:org) { space.organization }
    let(:api_call) { lambda { |user_headers| get "/v3/audit_events/#{event.guid}", nil, user_headers } }

    context 'when the audit_event does exist ' do
      context 'when the event happens in a space' do
        let(:event) {
          VCAP::CloudController::Event.make(
            type:              'audit.app.update',
            actor:             'some-user-guid',
            actor_type:        'some-user',
            actor_name:        'username',
            actor_username:    'system',
            actee:             'app-guid',
            actee_type:        'app',
            actee_name:        '',
            timestamp:         Sequel::CURRENT_TIMESTAMP,
            metadata:          {},
            space_guid:        space.guid,
          )
        }

        let(:event_json) do
          {
            'guid' => event.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'type' => 'audit.app.update',
            'actor' => {
              'guid' => 'some-user-guid',
              'type' => 'some-user',
              'name' => 'username'
            },
            'target' => {
              'guid' => 'app-guid',
              'type' => 'app',
              'name' => ''
            },
            'data' => {
            },
            'space' => {
              'guid' => space.guid
            },
            'organization' => {
              'guid' => space.organization.guid
            },
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/audit_events/#{event.guid}"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: event_json
          )
          h['space_manager'] = {
            code: 404,
            response_object: []
          }
          h['org_manager'] = {
            code: 404,
            response_object: []
          }
          h['org_billing_manager'] = {
            code: 404,
            response_object: []
          }
          h['no_role'] = {
            code: 404,
            response_object: []
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

        context 'and the space has been deleted' do
          before do
            delete "/v3/spaces/#{space.guid}", nil, admin_header
          end

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_object: event_json
            )
            h.freeze
          end

          it_behaves_like 'permissions for single object endpoint', %w(admin admin_read_only global_auditor org_auditor)
        end
      end

      context 'when the event happens in an org' do
        let(:event) {
          VCAP::CloudController::Event.make(
            type:              'audit.organization.update',
            actor:             'some-user-guid',
            actor_type:        'some-user',
            actor_name:        'username',
            actor_username:    'system',
            actee:             org.guid,
            actee_type:        'organization',
            actee_name:        '',
            timestamp:         Sequel::CURRENT_TIMESTAMP,
            metadata:          {},
            space:             nil,
            space_guid:        '',
            organization_guid: org.guid
          )
        }

        let(:event_json) do
          {
            'guid' => event.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'type' => 'audit.organization.update',
            'actor' => {
              'guid' => 'some-user-guid',
              'type' => 'some-user',
              'name' => 'username'
            },
            'target' => {
              'guid' => org.guid,
              'type' => 'organization',
              'name' => ''
            },
            'data' => {},
            'space' => nil,
            'organization' => {
              'guid' => org.guid
            },
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/audit_events/#{event.guid}"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 200,
            response_object: event_json
          )
          h['space_auditor'] = {
            code: 404,
            response_object: []
          }
          h['space_developer'] = {
            code: 404,
            response_object: []
          }
          h['space_manager'] = {
            code: 404,
            response_object: []
          }
          h['org_manager'] = {
            code: 404,
            response_object: []
          }
          h['org_billing_manager'] = {
            code: 404,
            response_object: []
          }
          h['no_role'] = {
            code: 404,
            response_object: []
          }
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

        context 'and the org has been deleted' do
          before do
            delete "/v3/organizations/#{org.guid}", nil, admin_header
          end

          let(:expected_codes_and_responses) do
            h = Hash.new(
              code: 200,
              response_object: event_json
            )
            h.freeze
          end

          it_behaves_like 'permissions for single object endpoint', %w(admin admin_read_only global_auditor)
        end
      end

      context 'when the event has neither space nor org' do
        let(:event) {
          VCAP::CloudController::Event.create(
            type:              'blob.remove_orphan',
            actor:             'system',
            actor_type:        'system',
            actor_name:        'system',
            actor_username:    'system',
            actee:             'directory_key/blob_key',
            actee_type:        'blob',
            actee_name:        '',
            timestamp:         Sequel::CURRENT_TIMESTAMP,
            metadata:          {},
            space_guid:        '',
            organization_guid: ''
          )
        }

        let(:event_json) do
          {
            'guid' => event.guid,
            'created_at' => iso8601,
            'updated_at' => iso8601,
            'type' => 'blob.remove_orphan',
            'actor' => {
              'guid' => 'system',
              'type' => 'system',
              'name' => 'system'
            },
            'target' => {
              'guid' => 'directory_key/blob_key',
              'type' => 'blob',
              'name' => ''
            },
            'data' => {},
            'space' => nil,
            'organization' => nil,
            'links' => {
              'self' => {
                'href' => "#{link_prefix}/v3/audit_events/#{event.guid}"
              }
            }
          }
        end

        let(:expected_codes_and_responses) do
          h = Hash.new(
            code: 404,
            response_object: []
          )
          %w(admin admin_read_only global_auditor).each do |role|
            h[role] = {
              code: 200,
              response_object: event_json
            }
          end
          h.freeze
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    context 'when the audit_event does not exist' do
      it 'returns a 404' do
        get '/v3/audit_events/does-not-exist', nil, admin_header
        expect(last_response.status).to eq 404
        expect(last_response).to have_error_message('Event not found')
      end
    end

    context 'when the user is not logged in' do
      let(:event) {
        VCAP::CloudController::Event.make(
          type:              'audit.app.update',
          actor:             'some-user-guid',
          actor_type:        'some-user',
          actor_name:        'username',
          actor_username:    'system',
          actee:             'app-guid',
          actee_type:        'app',
          actee_name:        '',
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          {},
          space_guid:        space.guid,
        )
      }

      it 'returns 401 for Unauthenticated requests' do
        get "/v3/audit_events/#{event.guid}", nil, base_json_headers
        expect(last_response.status).to eq(401)
      end
    end
  end
end
