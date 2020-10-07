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

    let!(:unscoped_event) { VCAP::CloudController::Event.make(actee: 'dir/key', type: 'blob.remove_orphan', organization_guid: '') }
    let!(:org_scoped_event) { VCAP::CloudController::Event.make(created_at: Time.now + 100, type: 'audit.organization.create', actee: org.guid, organization_guid: org.guid) }
    let!(:space_scoped_event) { VCAP::CloudController::Event.make(space_guid: space.guid, organization_guid: org.guid, actee: app_model.guid, type: 'audit.app.restart') }

    let(:unscoped_event_json) do
      {
        guid: unscoped_event.guid,
        created_at: iso8601,
        updated_at: iso8601,
        type: 'blob.remove_orphan',
        actor: {
          guid: unscoped_event.actor,
          type: unscoped_event.actor_type,
          name: unscoped_event.actor_name
        },
        target: {
          guid: unscoped_event.actee,
          type: unscoped_event.actee_type,
          name: unscoped_event.actee_name
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
          guid: org_scoped_event.actor,
          type: org_scoped_event.actor_type,
          name: org_scoped_event.actor_name
        },
        target: {
          guid: org_scoped_event.actee,
          type: org_scoped_event.actee_type,
          name: org_scoped_event.actee_name
        },
        data: {},
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
          guid: space_scoped_event.actor,
          type: space_scoped_event.actor_type,
          name: space_scoped_event.actor_name
        },
        target: {
          guid: space_scoped_event.actee,
          type: space_scoped_event.actee_type,
          name: space_scoped_event.actee_name
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

    context 'filtering out target_guids' do
      it 'returns filtered events without the specified target guid' do
        get "/v3/audit_events?target_guids[not]=#{app_model.guid}", nil, admin_header

        expect({
          resources: parsed_response['resources']
        }).to match_json_response({
          resources: [unscoped_event_json, org_scoped_event_json]
        })
      end

      it 'works for multiple guids' do
        get "/v3/audit_events?target_guids[not]=#{app_model.guid},#{org.guid}", nil, admin_header

        expect({
          resources: parsed_response['resources']
        }).to match_json_response({
          resources: [unscoped_event_json]
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

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::Event }
      let(:headers) { admin_headers }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/audit_events?#{filters}", nil, headers }
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
            organization_guid: org.guid,
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
          responses_for_space_restricted_single_endpoint(
            event_json,
            permitted_roles: %w(
              admin
              admin_read_only
              global_auditor
              org_auditor
              space_auditor
              space_developer
            )
          )
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
