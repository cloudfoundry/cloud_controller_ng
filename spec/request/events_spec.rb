require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Events' do
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
