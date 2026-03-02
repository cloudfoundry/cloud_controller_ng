require 'spec_helper'
require 'request_spec_shared_examples'
require_relative 'shared_context'

# Split from spec/request/routes_spec.rb for better test parallelization

RSpec.describe 'Routes Request' do
  include_context 'routes request spec'

  describe 'GET /v3/routes/:guid/relationships/shared_spaces' do
    let(:api_call) { ->(user_headers) { get "/v3/routes/#{guid}/relationships/shared_spaces", nil, user_headers } }
    let(:target_space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:route) do
      route = VCAP::CloudController::Route.make(space:)
      route.add_shared_space(target_space_1)
      route
    end
    let(:guid) { route.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space_1.add_developer(user)
    end

    describe 'permissions' do
      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS do
        let(:expected_codes_and_responses) do
          h = Hash.new({ code: 200, response_object: {
            data: [
              {
                guid: target_space_1.guid
              }
            ],
            links: {
              self: { href: %r{#{Regexp.escape(link_prefix)}/v3/routes/#{route.guid}/relationships/shared_spaces} }
            }
          } }.freeze)

          h['org_billing_manager'] = { code: 404 }
          h['no_role'] = { code: 404 }
          h
        end
      end
    end

    describe 'when route_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to unshare routes' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: route_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330_002
            }
          )
        )
      end
    end

    it 'responds with 404 when the route does not exist' do
      get '/v3/routes/some-fake-guid/relationships/shared_spaces', nil, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Route not found',
            'title' => 'CF-ResourceNotFound'
          }
        )
      )
    end
  end

  describe 'POST /v3/routes/:guid/relationships/shared_spaces' do
    let(:api_call) { ->(user_headers) { post "/v3/routes/#{guid}/relationships/shared_spaces", request_body.to_json, user_headers } }
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
    let(:route) { VCAP::CloudController::Route.make(space:) }
    let(:guid) { route.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space_1.add_developer(user)
      target_space_2.add_developer(user)
    end

    describe 'permissions' do
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)

        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h['admin'] = { code: 200 }
        h['space_developer'] = { code: 200 }
        h['space_supporter'] = { code: 200 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when target organization is suspended' do
        let(:target_space_1) do
          space = VCAP::CloudController::Space.make
          space.organization.add_user(user)
          space.organization.update(status: VCAP::CloudController::Organization::SUSPENDED)
          space
        end

        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 422 } }
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    it 'shares the route to the target space and logs audit event' do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(200)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.route.share',
                                        actor: user.guid,
                                        actee_type: 'route',
                                        actee_name: route.host,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata['target_space_guids']).to include(target_space_1.guid, target_space_2.guid)

      route.reload
      expect(route.shared_spaces).to include(target_space_1, target_space_2)
    end

    it 'reports that the route is now shared' do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(200)
      route.reload
      expect(route.shared_spaces).to include(target_space_1, target_space_2)
      expect(route).to be_shared
    end

    it 'reports that the route is not shared when it has not been shared' do
      route.reload
      expect(route.shared_spaces).to be_empty
      expect(route).not_to be_shared
    end

    describe 'when route_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to share routes' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: route_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330_002
            }
          )
        )
      end
    end

    it 'responds with 404 when the route does not exist' do
      post '/v3/routes/some-fake-guid/relationships/shared_spaces', request_body.to_json, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Route not found',
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
                'detail' => "Unable to share route #{route.uri} with spaces ['#{target_space_guid}']. " \
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

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share route #{route.uri} with spaces ['#{no_access_target_space.guid}']. " \
                            'Ensure the spaces exist and that you have access to them.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )

          route.reload
          expect(route).not_to be_shared
        end
      end

      context 'already owns the route' do
        let(:request_body) do
          {
            'data' => [
              { 'guid' => space.guid },
              { 'guid' => target_space_1.guid }
            ]
          }
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to share route '#{route.uri}' with space '#{space.guid}'. " \
                            'Routes cannot be shared into the space where they were created.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )

          route.reload
          expect(route).not_to be_shared
        end
      end
    end

    describe 'errors while sharing' do
      # isolation segments?
    end
  end

  describe 'DELETE /v3/routes/:guid/relationships/shared_spaces/:space_guid' do
    let(:api_call) { ->(user_headers) { delete "/v3/routes/#{guid}/relationships/shared_spaces/#{unshared_space_guid}", request_body.to_json, user_headers } }
    let(:target_space_1) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_2) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_3) { VCAP::CloudController::Space.make(organization: org) }
    let(:target_space_not_shared_with_route) { VCAP::CloudController::Space.make(organization: org) }
    let(:space_to_unshare) { target_space_2 }
    let(:unshared_space_guid) { space_to_unshare.guid }
    let(:request_body) { {} }
    let(:route) do
      route = VCAP::CloudController::Route.make(space:)
      route.add_shared_space(target_space_1)
      route.add_shared_space(target_space_2)
      route.add_shared_space(target_space_3)
      route
    end
    let(:guid) { route.guid }
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space_1.add_developer(user)
      target_space_2.add_developer(user)
      target_space_not_shared_with_route.add_developer(user)
    end

    describe 'permissions' do
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)

        h['org_billing_manager'] = { code: 404 }
        h['no_role'] = { code: 404 }

        h['admin'] = { code: 204 }
        h['space_developer'] = { code: 204 }
        h['space_supporter'] = { code: 204 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when target organization is suspended' do
        let(:space_to_unshare) do
          space = VCAP::CloudController::Space.make
          space.organization.add_user(user)
          space.add_developer(user)
          space.organization.update(status: VCAP::CloudController::Organization::SUSPENDED)
          space
        end

        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer space_supporter].each do |r|
            h[r] = {
              code: 422,
              errors: [{
                detail: "Unable to unshare route '#{route.uri}' from space '#{space_to_unshare.guid}'. The target organization is suspended.",
                title: 'CF-UnprocessableEntity',
                code: 10_008
              }]
            }
          end
          h
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    it 'unshares the specified route from the target space and logs audit event' do
      expect(route.shared_spaces).to include(target_space_1, space_to_unshare, target_space_3)

      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(204)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.route.unshare',
                                        actor: user.guid,
                                        actee_type: 'route',
                                        actee_name: route.host,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata['target_space_guid']).to eq(unshared_space_guid)

      route.reload
      expect(route.shared_spaces).to include(target_space_1, target_space_3)
    end

    describe 'when route_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to unshare routes' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: route_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330_002
            }
          )
        )
      end
    end

    it 'responds with 204 when the route is not shared with the specified space' do
      delete "/v3/routes/#{route.guid}/relationships/shared_spaces/#{target_space_not_shared_with_route.guid}", request_body.to_json, space_dev_headers

      expect(last_response.status).to eq(204)
    end

    it "responds with 404 when the route doesn't exist" do
      delete "/v3/routes/some-fake-guid/relationships/shared_spaces/#{target_space_1.guid}", request_body.to_json, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Route not found',
            'title' => 'CF-ResourceNotFound'
          }
        )
      )
    end

    context 'attempting to unshare from space that owns us' do
      let(:space_to_unshare) { space }

      it 'responds with 422 and does not unshare the roue' do
        api_call.call(space_dev_headers)

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => "Unable to unshare route '#{route.uri}' from space " \
                          "'#{space.guid}'. Routes cannot be removed from the space that owns them.",
              'title' => 'CF-UnprocessableEntity'
            }
          )
        )

        route.reload
        expect(route.shared_spaces).to contain_exactly(target_space_1, target_space_2, target_space_3)
      end
    end

    describe 'target space to unshare with' do
      context 'does not exist' do
        let(:unshared_space_guid) { 'fake-target' }

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to unshare route '#{route.uri}' from space '#{unshared_space_guid}'. " \
                            'Ensure the space exists and that you have access to it.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end

      context 'user does not have read access to the target space' do
        let(:unshared_space_guid) { VCAP::CloudController::Space.make(organization: org).guid }

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to unshare route '#{route.uri}' from space '#{unshared_space_guid}'. " \
                            'Ensure the space exists and that you have access to it.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end

      context 'user does not have write access to the target space' do
        let(:no_write_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:unshared_space_guid) { no_write_access_target_space.guid }

        before do
          no_write_access_target_space.add_auditor(user)
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to unshare route '#{route.uri}' from space '#{no_write_access_target_space.guid}'. " \
                            "You don't have write permission for the target space.",
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end
    end
  end

  describe 'PATCH /v3/routes/:guid/relationships/space' do
    let(:shared_domain) { VCAP::CloudController::SharedDomain.make }
    let(:route) { VCAP::CloudController::Route.make(space: space, domain: shared_domain) }
    let(:api_call) { ->(user_headers) { patch "/v3/routes/#{route.guid}/relationships/space", request_body.to_json, user_headers } }
    let(:target_space) { VCAP::CloudController::Space.make(organization: org) }
    let(:request_body) do
      {
        data: { 'guid' => target_space.guid }
      }
    end
    let(:space_dev_headers) do
      org.add_user(user)
      space.add_developer(user)
      headers_for(user)
    end
    let!(:feature_flag) do
      VCAP::CloudController::FeatureFlag.make(name: 'route_sharing', enabled: true, error_message: nil)
    end

    before do
      org.add_user(user)
      target_space.add_developer(user)
    end

    context 'when the user logged in' do
      let(:expected_codes_and_responses) do
        h = Hash.new({ code: 403, errors: CF_NOT_AUTHORIZED }.freeze)
        h['admin'] = { code: 200 }
        h['no_role'] = { code: 404 }
        h['org_billing_manager'] = { code: 404 }
        h['space_developer'] = { code: 200 }
        h
      end

      it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS

      context 'when organization is suspended' do
        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer].each { |r| h[r] = { code: 403, errors: CF_ORG_SUSPENDED } }
          h
        end

        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end

      context 'when target organization is suspended' do
        let(:suspended_space) { VCAP::CloudController::Space.make }
        let(:request_body) do
          {
            data: { 'guid' => suspended_space.guid }
          }
        end

        let(:expected_codes_and_responses) do
          h = super()
          %w[space_developer].each do |r|
            h[r] = {
              code: 422,
              errors: [{
                detail: "Unable to transfer owner of route '#{route.uri}' to space '#{suspended_space.guid}'. The target organization is suspended.",
                title: 'CF-UnprocessableEntity',
                code: 10_008
              }]
            }
          end
          h
        end

        before do
          suspended_space.organization.add_user(user)
          suspended_space.add_developer(user)
          suspended_space.organization.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end

        it_behaves_like 'permissions for single object endpoint', ALL_PERMISSIONS
      end
    end

    it 'changes the route owner to the given space and logs an event', isolation: :truncation do
      api_call.call(space_dev_headers)

      expect(last_response.status).to eq(200)

      event = VCAP::CloudController::Event.last
      expect(event.values).to include({
                                        type: 'audit.route.transfer-owner',
                                        actor: user.guid,
                                        actee_type: 'route',
                                        actee_name: route.host,
                                        space_guid: space.guid,
                                        organization_guid: space.organization.guid
                                      })
      expect(event.metadata['target_space_guid']).to eq(target_space.guid)

      route.reload
      expect(route.space).to eq target_space
    end

    describe 'when using a private domain' do
      let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }
      let(:route) { VCAP::CloudController::Route.make(space: space, domain: private_domain) }
      let(:second_org) { VCAP::CloudController::Organization.make }
      let(:another_space) { VCAP::CloudController::Space.make(organization: second_org) }
      let(:request_body) do
        {
          data: { 'guid' => another_space.guid }
        }
      end
      let(:space_dev_headers) do
        org.add_user(user)
        space.add_developer(user)
        second_org.add_user(user)
        another_space.add_developer(user)
        headers_for(user)
      end

      it 'responds with 422' do
        api_call.call(space_dev_headers)

        expect(last_response.status).to eq(422)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => "Unable to transfer owner of route '#{route.uri}' to space '#{another_space.guid}'. " \
                          "Target space does not have access to route's domain",
              'title' => 'CF-UnprocessableEntity'
            }
          )
        )
      end
    end

    describe 'target space to transfer to' do
      context 'does not exist' do
        let(:target_space_guid) { 'fake-target' }
        let(:request_body) do
          {
            data: { 'guid' => target_space_guid }
          }
        end

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to transfer owner of route '#{route.uri}' to space '#{target_space_guid}'. " \
                            'Ensure the space exists and that you have access to it.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end

      context 'user does not have read access to the target space' do
        let(:no_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:request_body) do
          {
            data: { 'guid' => no_access_target_space.guid }
          }
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to transfer owner of route '#{route.uri}' to space '#{no_access_target_space.guid}'. " \
                            'Ensure the space exists and that you have access to it.',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end

      context 'user does not have write access to the target space' do
        let(:no_write_access_target_space) { VCAP::CloudController::Space.make(organization: org) }
        let(:request_body) do
          {
            data: { 'guid' => no_write_access_target_space.guid }
          }
        end

        before do
          no_write_access_target_space.add_auditor(user)
        end

        it 'responds with 422 and does not share the route' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => "Unable to transfer owner of route '#{route.uri}' to space '#{no_write_access_target_space.guid}'. " \
                            "You don't have write permission for the target space.",
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end
    end

    it 'responds with 404 when the route does not exist' do
      patch '/v3/routes/some-fake-guid/relationships/space', request_body.to_json, space_dev_headers

      expect(last_response).to have_status_code(404)
      expect(parsed_response['errors']).to include(
        include(
          {
            'detail' => 'Route not found',
            'title' => 'CF-ResourceNotFound'
          }
        )
      )
    end

    describe 'when the request body is invalid' do
      context 'when there are additional keys' do
        let(:request_body) do
          {
            data: { 'guid' => target_space.guid },
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

      context 'when data is not a hash' do
        let(:request_body) do
          {
            data: [{ 'guid' => target_space.guid }]
          }
        end

        it 'responds with 422' do
          api_call.call(space_dev_headers)

          expect(last_response.status).to eq(422)
          expect(parsed_response['errors']).to include(
            include(
              {
                'detail' => 'Data must be an object',
                'title' => 'CF-UnprocessableEntity'
              }
            )
          )
        end
      end
    end

    describe 'when route_sharing flag is disabled' do
      before do
        feature_flag.enabled = false
        feature_flag.save
      end

      it 'makes users unable to transfer-owner' do
        api_call.call(space_dev_headers)

        expect(last_response).to have_status_code(403)
        expect(parsed_response['errors']).to include(
          include(
            {
              'detail' => 'Feature Disabled: route_sharing',
              'title' => 'CF-FeatureDisabled',
              'code' => 330_002
            }
          )
        )
      end
    end
  end
end
