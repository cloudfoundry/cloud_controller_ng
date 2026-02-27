require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'V3 service instances - Sharing' do
  include_context 'service instances setup'

  describe 'POST /v3/service_instances/:guid/relationships/shared_spaces' do
    let(:api_call) { ->(user_headers) { post "/v3/service_instances/#{guid}/relationships/shared_spaces", request_body.to_json, user_headers } }
    let(:target_space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_2) { VCAP::CloudController::Space.make(organization: org) }
    let(:request_body) do
      {
        'data' => [
          { 'guid' => target_space_1.guid },
          { 'guid' => target_space_2.guid }
        ]
      }
    end
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space:) }
    let(:guid) { service_instance.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space_1.add_developer(user)
      target_space_2.add_developer(user)
    end

    context 'permissions' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) { responses_for_space_restricted_update_endpoint(success_code: 200) }
      end

      it_behaves_like 'permissions for update endpoint when organization is suspended', 200

      context 'when target organization is suspended' do
        let(:target_space_1) do
          space = VCAP::CloudController::Space.make
          space.organization.add_user(user)
          space.organization.update(status: VCAP::CloudController::Organization::SUSPENDED)
          space
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
          let(:expected_codes_and_responses) do
            responses_for_org_suspended_space_restricted_update_endpoint(success_code: 200).merge({ 'space_developer' => { code: 422 } })
          end
        end
      end
    end

    it 'shares the service instance to the target space and logs audit event' do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(200)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.service_instance.share',
                                        actor: user.guid,
                                        actee_type: 'service_instance',
                                        actee_name: service_instance.name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata['target_space_guids']).to include(target_space_1.guid, target_space_2.guid)

      service_instance.reload
      expect(service_instance.shared_spaces).to include(target_space_1, target_space_2)
    end

    describe 'when service_instance_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to share services' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: service_instance_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330_002
            }
          )
        )
      end
    end

    it 'responds with 404 when the instance does not exist' do
      post '/v3/service_instances/some-fake-guid/relationships/shared_spaces', request_body.to_json, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Service instance not found',
            'title' => 'CF-ResourceNotFound'
          }
        )
      )
    end

    describe 'when the request body is invalid' do
      context 'when it is not a valid relationship' do
        let(:request_body) do
          {
            'data' => { 'guid' => target_space_1.guid }
          }
        end

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => 'Data must be an array',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end

      context 'when there are additional keys' do
        let(:request_body) do
          {
            'data' => [
              { 'guid' => target_space_1.guid }
            ],
            'fake-key' => 'foo'
          }
        end

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unknown field(s): 'fake-key'",
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end
    end

    describe 'target space to share to' do
      context 'does not exist' do
        let(:target_space_guid) { 'fake-target' }
        let(:request_body) do
          {
            'data' => [
              { 'guid' => target_space_guid }
            ]
          }
        end

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share service instance #{service_instance.name} with spaces ['#{target_space_guid}']. " \
                            'Ensure the spaces exist and that you have access to them.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end

      context 'user does not have access to one of the target spaces' do
        let(:no_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:request_body) do
          {
            'data' => [
              { 'guid' => no_access_target_space.guid },
              { 'guid' => target_space_1.guid }
            ]
          }
        end

        it 'responds with 422 and does not share the instance' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share service instance #{service_instance.name} with spaces ['#{no_access_target_space.guid}']. " \
                            'Ensure the spaces exist and that you have access to them.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )

          service_instance.reload
          expect(service_instance).not_to be_shared
        end
      end

      context 'owns the space' do
        let(:no_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:request_body) do
          {
            'data' => [
              { 'guid' => space.guid },
              { 'guid' => target_space_1.guid }
            ]
          }
        end

        it 'responds with 422 and does not share the instance' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share service instance '#{service_instance.name}' with space '#{space.guid}'. " \
                            'Service instances cannot be shared into the space where they were created.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )

          service_instance.reload
          expect(service_instance).not_to be_shared
        end
      end
    end

    describe 'errors while sharing' do
      context 'service instance is user provided' do
        let(:service_instance) { VCAP::CloudController::UserProvidedServiceInstance.make(space:) }

        it 'responds with 422 and the error' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => 'User-provided services cannot be shared.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end
    end
  end

  describe 'DELETE /v3/service_instances/:guid/relationships/shared_spaces/:space_guid' do
    let(:api_call) { ->(user_headers) { delete "/v3/service_instances/#{guid}/relationships/shared_spaces/#{space_guid}", nil, user_headers } }
    let(:target_space) { VCAP::CloudController::Space.make(organization: org) }
    let(:service_instance) { VCAP::CloudController::ManagedServiceInstance.make(space:) }
    let(:guid) { service_instance.guid }
    let(:space_guid) { target_space.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'service_instance_sharing', enabled: true, error_message: nil)
    end

    before do
      share_service_instance(service_instance, target_space)
    end

    context 'permissions' do
      let(:db_check) do
        lambda {
          si = VCAP::CloudController::ServiceInstance.first(guid:)
          expect(si).not_to be_shared
        }
      end

      it_behaves_like 'permissions for delete endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) { responses_for_space_restricted_delete_endpoint }
      end

      it_behaves_like 'permissions for delete endpoint when organization is suspended', 204
    end

    it 'unshares the service instance from the target space and logs audit event' do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(204)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.service_instance.unshare',
                                        actor: user.guid,
                                        actee_type: 'service_instance',
                                        actee_name: service_instance.name,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata['target_space_guid']).to eq(target_space.guid)
    end

    describe 'when there are bindings in the shared space' do
      let(:app_1) { VCAP::CloudController::AppModel.make(space: target_space) }
      let(:app_2) { VCAP::CloudController::AppModel.make(space: target_space) }

      let(:binding_1) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: app_1) }
      let(:binding_2) { VCAP::CloudController::ServiceBinding.make(service_instance: service_instance, app: app_2) }

      context 'and the bindings can be deleted synchronously' do
        before do
          stub_unbind(binding_1, accepts_incomplete: true, status: 200, body: {}.to_json)
          stub_unbind(binding_2, accepts_incomplete: true, status: 200, body: {}.to_json)
        end

        it 'deletes all bindings and successfully unshares' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(204)

          service_instance.reload
          expect(service_instance).not_to be_shared
          expect(service_instance).not_to have_bindings
        end
      end

      context 'but the bindings can only be deleted asynchronously' do
        before do
          stub_unbind(binding_1, accepts_incomplete: true, status: 202, body: {}.to_json)
          stub_unbind(binding_2, accepts_incomplete: true, status: 200, body: {}.to_json)
        end

        it 'responds with 502 and does not unshare' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(502)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unshare of service instance failed: \n\nUnshare of service instance failed because one or more bindings could not be deleted.\n\n " \
                            "\tThe binding between an application and service instance #{service_instance.name} in space #{target_space.name} is being deleted asynchronously.",
                'title' => 'CF-ServiceInstanceUnshareFailed'
              }
            )
          )

          expect(service_instance).to be_shared
        end
      end
    end

    it 'responds with 404 when the instance does not exist' do
      delete "/v3/service_instances/some-fake-guid/relationships/shared_spaces/#{space_guid}",
             nil,
             space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Service instance not found',
            'title' => 'CF-ResourceNotFound'
          }
        )
      )
    end

    describe 'target space to unshare from' do
      context 'when it does not exist' do
        let(:space_guid) { 'fake-target' }

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to unshare service instance from space #{space_guid}. " \
                            'Ensure the space exists.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end

      context 'when instance was not shared to the space' do
        let(:space_guid) { VCAP::CloudController::Space.make(organization: org).guid }

        it 'responds with 204' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(204)
        end
      end
    end
  end

  describe 'GET /v3/service_instances/:guid/relationships/shared_spaces' do
    let(:user_header) { headers_for(user) }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:) }
    let(:other_space) { VCAP::CloudController::Space.make }

    before do
      share_service_instance(instance, other_space)
    end

    describe 'permissions in originating space' do
      let(:api_call) { ->(user_headers) { get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces", nil, user_headers } }

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_response) do
          {
            data: [{ guid: other_space.guid }],
            links: {
              self: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces" }
            }
          }
        end

        let(:expected_codes_and_responses) do
          responses_for_space_restricted_single_endpoint(expected_response)
        end
      end
    end

    it 'respond with 200 when the user cannot read the originating space, but has access to the service instance' do
      set_current_user_as_role(role: 'space_developer', org: other_space.organization, space: other_space, user: user)
      get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces", nil, user_header
      expect(last_response.status).to eq(200)
    end

    describe 'fields' do
      it 'can include the space name, guid and organization relationship fields' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space]=name,guid,relationships.organization", nil, admin_headers
        expect(last_response).to have_status_code(200)

        r = { organization: { data: { guid: other_space.organization.guid } } }
        included = {
          spaces: [
            { name: other_space.name, guid: other_space.guid, relationships: r }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: })
      end

      it 'can include the organization name and guid fields through space' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space.organization]=name,guid", nil, admin_headers
        expect(last_response).to have_status_code(200)

        included = {
          organizations: [
            {
              name: other_space.organization.name,
              guid: other_space.organization.guid
            }
          ]
        }

        expect({ included: parsed_response['included'] }).to match_json_response({ included: })
      end

      context 'when the user can read from the originating space only' do
        before do
          set_current_user_as_role(role: 'space_developer', org: space.organization, space: space, user: user)
        end

        it 'does not include space and organization names of the shared space' do
          get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space]=name,guid,relationships.organization&fields[space.organization]=name,guid", nil,
              user_header
          expect(last_response).to have_status_code(200)

          included = {
            spaces: [
              { guid: other_space.guid, relationships: { organization: { data: { guid: other_space.organization.guid } } } }
            ],
            organizations: [
              { guid: other_space.organization.guid }
            ]
          }

          expect({ included: parsed_response['included'] }).to match_json_response({ included: })
        end
      end

      it 'fails for invalid resources' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[fruit]=name", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(
          include(
            'detail' => "The query parameter is invalid: Fields [fruit] valid resources are: 'space', 'space.organization'"
          )
        )
      end

      it 'fails for not allowed space fields' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space]=metadata", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(
          include(
            'detail' => "The query parameter is invalid: Fields valid keys for 'space' are: 'name', 'guid', 'relationships.organization'"
          )
        )
      end

      it 'fails for not allowed space.organization fields' do
        get "/v3/service_instances/#{instance.guid}/relationships/shared_spaces?fields[space.organization]=metadata", nil, admin_headers
        expect(last_response).to have_status_code(400)
        expect(parsed_response['errors']).to include(
          include(
            'detail' => "The query parameter is invalid: Fields valid keys for 'space.organization' are: 'name', 'guid'"
          )
        )
      end
    end
  end

  describe 'GET /v3/service_instances/:guid/relationships/shared_spaces/usage_summary' do
    let(:guid) { instance.guid }
    let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:) }
    let(:space_1) { VCAP::CloudController::Space.make }
    let(:space_2) { VCAP::CloudController::Space.make }
    let(:space_3) { VCAP::CloudController::Space.make }
    let(:url) { "/v3/service_instances/#{guid}/relationships/shared_spaces/usage_summary" }
    let(:api_call) { ->(user_headers) { get url, nil, user_headers } }
    let(:bindings_on_space_1) { 1 }
    let(:bindings_on_space_2) { 3 }

    def create_bindings(instance, space:, count:)
      (1..count).each do
        VCAP::CloudController::ServiceBinding.make(
          app: VCAP::CloudController::AppModel.make(space:),
          service_instance: instance
        )
      end
    end

    before do
      share_service_instance(instance, space_1)
      share_service_instance(instance, space_2)
      share_service_instance(instance, space_3)

      create_bindings(instance, space: space_1, count: bindings_on_space_1)
      create_bindings(instance, space: space_2, count: bindings_on_space_2)
    end

    context 'permissions' do
      let(:response_object) do
        {
          usage_summary: [
            { space: { guid: space_1.guid }, bound_app_count: bindings_on_space_1 },
            { space: { guid: space_2.guid }, bound_app_count: bindings_on_space_2 },
            { space: { guid: space_3.guid }, bound_app_count: 0 }
          ],
          links: {
            self: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces/usage_summary" },
            shared_spaces: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}/relationships/shared_spaces" },
            service_instance: { href: "#{link_prefix}/v3/service_instances/#{instance.guid}" }
          }
        }
      end

      let(:expected_codes_and_responses) do
        responses_for_space_restricted_single_endpoint(response_object)
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
    end

    context 'when the instance does not exist' do
      let(:guid) { 'a-fake-guid' }

      it 'responds with 404 Not Found' do
        api_call.call(admin_headers)
        expect(last_response).to have_status_code(404)
      end
    end

    context 'when the user has access to the service through a shared space' do
      it 'responds with 200 ok' do
        user = VCAP::CloudController::User.make
        set_current_user_as_role(role: 'space_developer', org: space_2.organization, space: space_2, user: user)

        api_call.call(headers_for(user))

        expect(last_response).to have_status_code(200)
      end
    end
  end

  describe 'GET /v3/service_instances/:guid/permissions' do
    # For this endpoint we also want to test the 'cloud_controller_service_permissions.read' scope as well as unauthenticated calls.
    ADDITIONAL_PERMISSIONS_TO_TEST = %w[service_permissions_reader unauthenticated].freeze

    READ_AND_WRITE = { code: 200, response_object: { manage: true, read: true } }.freeze
    READ_ONLY = { code: 200, response_object: { manage: false, read: true } }.freeze
    NO_PERMISSIONS = { code: 200, response_object: { manage: false, read: false } }.freeze

    let(:api_call) { ->(user_headers) { get "/v3/service_instances/#{guid}/permissions", nil, user_headers } }

    context 'when the service instance does not exist' do
      let(:guid) { 'no-such-guid' }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 404 }.freeze)
        h['unauthenticated'] = { code: 401 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ADDITIONAL_PERMISSIONS_TO_TEST
    end

    context 'when the user is a member of the org or space the service instance exists in' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space:) }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 404 }.freeze)
        %w[admin space_developer].each { |r| h[r] = READ_AND_WRITE }
        %w[admin_read_only global_auditor org_manager space_manager space_auditor space_supporter].each { |r| h[r] = READ_ONLY }
        %w[org_billing_manager org_auditor no_role service_permissions_reader].each { |r| h[r] = NO_PERMISSIONS }
        h['unauthenticated'] = { code: 401 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ADDITIONAL_PERMISSIONS_TO_TEST

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          h['space_developer'] = READ_ONLY
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ADDITIONAL_PERMISSIONS_TO_TEST
      end

      context 'request with only the cloud_controller_service_permissions.read scope' do
        it_behaves_like 'permissions for single object endpoint', LOCAL_ROLES do
          let(:after_request_check) do
            lambda do
              # Store the HTTP status and response from the original call.
              expected_status_code = last_response.status
              expected_json_response = parsed_response

              # Repeat the same call for the same user, but now with only the 'cloud_controller_service_permissions.read' scope.
              api_call.call(set_user_with_header_as_service_permissions_reader(user:))

              # Both the HTTP status and response should be the same.
              expect(last_response).to have_status_code(expected_status_code)
              expect(parsed_response).to match_json_response(expected_json_response)
            end
          end
        end
      end
    end

    context 'when the user is not a member of the org or space the service instance exists in' do
      let(:instance) { VCAP::CloudController::ManagedServiceInstance.make }
      let(:guid) { instance.guid }

      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 404 }.freeze)
        h['admin'] = READ_AND_WRITE
        %w[admin_read_only global_auditor].each { |r| h[r] = READ_ONLY }
        %w[org_billing_manager org_auditor org_manager space_manager space_auditor space_developer space_supporter no_role service_permissions_reader].each do |r|
          h[r] = NO_PERMISSIONS
        end
        h['unauthenticated'] = { code: 401 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS + ADDITIONAL_PERMISSIONS_TO_TEST
    end
  end

end
