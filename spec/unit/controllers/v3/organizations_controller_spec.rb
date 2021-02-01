require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe OrganizationsV3Controller, type: :controller do
  describe '#show' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:org) { VCAP::CloudController::Organization.make(name: 'Eric\'s Farm') }
    let!(:space) { VCAP::CloudController::Space.make(name: 'Cat', organization: org) }

    describe 'permissions by role' do
      before do
        set_current_user(user)
      end

      role_to_expected_http_response = {
        'admin' => 200,
        'space_developer' => 200,
        'admin_read_only' => 200,
        'global_auditor' => 200,
        'space_manager' => 200,
        'space_auditor' => 200,
        'org_manager' => 200,
        'org_auditor' => 200,
        'org_billing_manager' => 200,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            get :show, params: { guid: org.guid }, as: :json

            expect(response.status).to eq(expected_return_value),
              "Expected #{expected_return_value}, but got #{response.status}. Response: #{response.body}"
            if expected_return_value == 200
              expect(parsed_body['guid']).to eq(org.guid)
              expect(parsed_body['name']).to eq('Eric\'s Farm')
              expect(parsed_body['suspended']).to be false
              expect(parsed_body['created_at']).to match(iso8601)
              expect(parsed_body['updated_at']).to match(iso8601)
              expect(parsed_body['links']['self']['href']).to match(%r{/v3/organizations/#{org.guid}$})
            end
          end
        end
      end

      context 'when the org is suspended' do
        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end
        role_to_expected_http_response.each do |role, expected_return_value|
          context "as an #{role}" do
            it "returns #{expected_return_value}" do
              set_current_user_as_role(role: role, org: org, space: space, user: user)

              get :show, params: { guid: org.guid }, as: :json

              expect(response.status).to eq(expected_return_value),
                "Expected #{expected_return_value}, but got #{response.status}. Response: #{response.body}"
              if expected_return_value == 200
                expect(parsed_body['guid']).to eq(org.guid)
                expect(parsed_body['name']).to eq('Eric\'s Farm')
                expect(parsed_body['suspended']).to be true
              end
            end
          end
        end
      end
    end

    describe 'user with no roles' do
      before do
        set_current_user(user)
      end

      it 'returns an error' do
        get :show, params: { guid: org.guid }, as: :json
        expect(response.status).to eq(404), "Got #{response.status}"
      end
    end
  end

  describe '#create' do
    let(:user) { VCAP::CloudController::User.make }
    let(:uaa_client) { instance_double(VCAP::CloudController::UaaClient) }
    before do
      set_current_user(user)
      allow(CloudController::DependencyLocator.instance).to receive(:uaa_client).and_return(uaa_client)
      allow(uaa_client).to receive(:usernames_for_ids).with([user.guid]).and_return(
        { user.guid => 'Ragnaros' }
      )
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 201,
        'admin_read_only' => 403,
        'global_auditor' => 403,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, user: user)

            post :create, params: { name: 'my-sweet-org' }, as: :json

            expect(response.status).to eq(expected_return_value),
              "Expected #{expected_return_value}, but got #{response.status}. Response: #{response.body}"
            if expected_return_value == 200
              expect(parsed_body['guid']).to eq(org.guid)
              expect(parsed_body['name']).to eq('Eric\'s Farm')
              expect(parsed_body['created_at']).to match(iso8601)
              expect(parsed_body['updated_at']).to match(iso8601)
              expect(parsed_body['links']['self']['href']).to match(%r{/v3/organizations/#{org.guid}$})
            end
          end
        end
      end
    end

    describe 'user with no roles' do
      it 'returns an error' do
        post :create, params: { name: 'bloop' }, as: :json
        expect(response.status).to eq(403), "Got #{response.status}"
      end
    end

    context 'when "user_org_creation" feature flag is enabled' do
      before do
        VCAP::CloudController::FeatureFlag.make(name: 'user_org_creation', enabled: true)
      end

      it 'lets ALL users create orgs' do
        post :create, params: { name: 'anarchy-reigns' }, as: :json
        expect(response.status).to eq(201), "Got #{response.status}"
      end

      context 'when the RoleCreate returns an error' do
        before do
          allow_any_instance_of(VCAP::CloudController::RoleCreate).to receive(:create_organization_role).
            and_raise(VCAP::CloudController::RoleCreate::Error.new('ya done goofed'))
        end

        it 'does not create the org and fails' do
          post :create, params: { name: 'bad-org' }, as: :json
          expect(response.status).to eq(422), "Got #{response.status}"
          expect(VCAP::CloudController::Organization.first(name: 'bad-org')).to be(nil)
        end
      end
    end

    context 'when the user is admin' do
      before do
        set_current_user_as_admin(user: user)
      end

      context 'when there is a message validation failure' do
        it 'displays an informative error' do
          post :create, params: { name: '' }, as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message("Name can't be blank")
        end
      end

      context 'when there is a model validation failure' do
        let(:name) { 'not-unique' }

        before do
          VCAP::CloudController::Organization.make name: name
        end

        it 'responds with 422' do
          post :create, params: { name: name }, as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message("Organization '#{name}' already exists.")
        end
      end

      context 'when there are too many annotations' do
        before do
          VCAP::CloudController::Config.config.set(:max_annotations_per_resource, 1)
        end

        it 'responds with 422' do
          post :create, params: {
            name: 'new-org',
            metadata: {
              annotations: {
                radish: 'daikon',
                potato: 'idaho'
              }
            }
          }, as: :json

          expect(response.status).to eq(422)
          expect(response).to have_error_message(/exceed maximum of 1/)
        end
      end
    end
  end

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:member_org) { VCAP::CloudController::Organization.make(name: 'Marmot') }
    let!(:manager_org) { VCAP::CloudController::Organization.make(name: 'Rat') }
    let!(:billing_manager_org) { VCAP::CloudController::Organization.make(name: 'Beaver') }
    let!(:auditor_org) { VCAP::CloudController::Organization.make(name: 'Capybara') }
    let!(:other_org) { VCAP::CloudController::Organization.make(name: 'Groundhog') }

    before do
      member_org.add_user(user)
      manager_org.add_manager(user)
      billing_manager_org.add_billing_manager(user)
      auditor_org.add_auditor(user)
    end

    it 'returns orgs the user has read access' do
      get :index

      expect(response.status).to eq(200)
      expect(parsed_body['resources'].map { |r| r['name'] }).to match_array([
        member_org.name, manager_org.name, billing_manager_org.name, auditor_org.name
      ])
    end

    it 'eager loads associated resources that the presenter specifies' do
      expect(VCAP::CloudController::OrgListFetcher).to receive(:fetch).with(
        hash_including(eager_loaded_associations: [:labels, :annotations, :quota_definition])
      ).and_call_original

      get :index

      expect(response.status).to eq(200)
    end

    describe 'query params' do
      describe 'names' do
        it 'returns orgs with matching names' do
          get :index, params: { names: 'Marmot,Beaver' }, as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['resources'].map { |r| r['name'] }).to match_array([
            'Marmot', 'Beaver'
          ])
        end
      end

      describe 'order_by' do
        it 'returns orgs sorted alphabetically by name' do
          get :index, params: { order_by: 'name' }, as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['resources'].map { |r| r['name'] }).to eql([
            'Beaver',
            'Capybara',
            'Marmot',
            'Rat',
          ])
        end
      end

      describe 'guids' do
        it 'returns orgs with matching guids' do
          get :index, params: { guids: "#{billing_manager_org.guid},#{member_org.guid}" }, as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['resources'].map { |r| r['guid'] }).to match_array([
            billing_manager_org.guid, member_org.guid
          ])
        end

        it 'does not return orgs that the user does not have access to' do
          get :index, params: { guids: "#{billing_manager_org.guid},#{member_org.guid},#{other_org.guid}" }, as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['resources'].map { |r| r['guid'] }).to match_array([
            billing_manager_org.guid, member_org.guid
          ])
        end
      end
    end

    describe 'query params errors' do
      context 'invalid param format' do
        it 'returns 400' do
          get :index, params: { per_page: 'meow' }, as: :json

          expect(response.status).to eq 400
          expect(response.body).to include('Per page must be a positive integer')
          expect(response.body).to include('BadQueryParameter')
        end
      end

      context 'unknown query param' do
        it 'returns 400' do
          get :index, params: { meow: 'bad-val', nyan: 'mow' }, as: :json

          expect(response.status).to eq 400
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s)')
          expect(response.body).to include('nyan')
          expect(response.body).to include('meow')
        end
      end
    end

    context 'when pagination options are specified' do
      let(:page) { 2 }
      let(:per_page) { 1 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }

      it 'paginates the response' do
        get :index, params: params, as: :json

        parsed_response = parsed_body
        expect(parsed_response['pagination']['total_results']).to eq(4)
        expect(parsed_response['resources'].length).to eq(per_page)
        expect(parsed_response['resources'][0]['name']).to eq('Rat')
      end
    end

    context 'when the user has global read access' do
      before do
        allow_user_global_read_access(user)
      end

      it 'returns a 200 and all organizations' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].length).to eq(6)
      end
    end

    context 'when accessed as an isolation segment subresource' do
      let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
      let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:org1) { VCAP::CloudController::Organization.make }
      let(:org2) { VCAP::CloudController::Organization.make }
      let(:org3) { VCAP::CloudController::Organization.make }

      before do
        VCAP::CloudController::Organization.make
        assigner.assign(isolation_segment_model, [org1, org2])
        org1.add_user(user)
        org2.add_user(user)
        org3.add_user(user)
      end

      it 'uses the isolation_segment as a filter' do
        get :index, params: { isolation_segment_guid: isolation_segment_model.guid }, as: :json

        expect(response.status).to eq(200)
        response_guids = parsed_body['resources'].map { |r| r['guid'] }
        expect(response_guids).to match_array([org1.guid, org2.guid])
      end

      it 'provides the correct base url in the pagination links' do
        get :index, params: { isolation_segment_guid: isolation_segment_model.guid }, as: :json
        expect(response.status).to eq(200)
        expect(parsed_body['pagination']['first']['href']).to include("/v3/isolation_segments/#{isolation_segment_model.guid}/organizations")
      end

      context 'when pagination options are specified' do
        let(:page) { 1 }
        let(:per_page) { 1 }
        let(:params) { { 'page' => page, 'per_page' => per_page, isolation_segment_guid: isolation_segment_model.guid } }

        it 'paginates the response' do
          get :index, params: params, as: :json

          parsed_response = parsed_body
          response_guids = parsed_response['resources'].map { |r| r['guid'] }
          expect(parsed_response['pagination']['total_results']).to eq(2)
          expect(response_guids.length).to eq(per_page)
        end
      end

      context 'the isolation_segment does not exist' do
        it 'returns a 404 Resource Not Found' do
          get :index, params: { isolation_segment_guid: 'not-an-iso-seg' }, as: :json

          expect(response.status).to eq 404
          expect(response.body).to include 'ResourceNotFound'
        end
      end

      context 'when the user does not have permissions to read the isolation_segment' do
        before do
          org1.remove_user(user)
          org2.remove_user(user)
        end

        it 'returns a 404 Resource Not Found error' do
          get :index, params: { isolation_segment_guid: isolation_segment_model.guid }, as: :json

          expect(response.body).to include 'ResourceNotFound'
          expect(response.status).to eq 404
        end
      end

      context 'when the isolation segment organizations contains organizations the user cannot see' do
        let(:org4) { VCAP::CloudController::Organization.make }

        before do
          assigner.assign(isolation_segment_model, [org4])
        end

        it 'only displays to me the organizations that the user can see' do
          get :index, params: { isolation_segment_guid: isolation_segment_model.guid }, as: :json

          expect(response.status).to eq 200
          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response_guids).to match_array([org1.guid, org2.guid])
        end
      end
    end
  end

  describe '#show_default_isolation_segment' do
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make(name: 'Water') }
    let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'default_seg') }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
    let(:unassigner) { VCAP::CloudController::IsolationSegmentUnassign.new }

    before do
      assigner.assign(isolation_segment, [org])
      org.update(default_isolation_segment_guid: isolation_segment.guid)
    end

    context 'with sufficient permissions' do
      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [org])
      end

      it 'presents the default isolation segment' do
        get :show_default_isolation_segment, params: { guid: org.guid }

        expect(response.status).to eq(200)
        expect(parsed_body['data']['guid']).to eq(isolation_segment.guid)
      end

      context 'when the organization does not exist' do
        it 'throws ResourceNotFound error' do
          get :show_default_isolation_segment, params: { guid: 'cest-ne-pas-un-org' }

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Organization not found'
        end
      end

      context 'when there is no default isolation segment' do
        before do
          org.update(default_isolation_segment_guid: nil)
        end

        it 'presents a null guid' do
          get :show_default_isolation_segment, params: { guid: org.guid }

          expect(response.status).to eq(200)
          expect(parsed_body['data']).to eq(nil)
        end
      end
    end

    context 'permissions' do
      context 'when the user does not have cloud_controller.read' do
        before do
          set_current_user(user, scopes: ['cloud_controller.write'])
        end

        it 'throws a NotAuthorized error' do
          get :show_default_isolation_segment, params: { guid: org.guid }

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end

      context 'when the user does not have permissions to read from organization' do
        before do
          set_current_user(user)
          allow_user_read_access_for(user)
        end

        it 'throws ResourceNotFound error' do
          get :show_default_isolation_segment, params: { guid: org.guid }

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Organization not found'
        end
      end
    end
  end

  describe '#update_default_isolation_segment' do
    let(:user) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make(name: 'Water') }
    let(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'default_seg') }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
    let(:unassigner) { VCAP::CloudController::IsolationSegmentUnassign.new }
    let(:request_body) do
      {
        data: { guid: isolation_segment.guid }
      }
    end

    before do
      set_current_user(user, { admin: true })
      allow_user_read_access_for(user, orgs: [org])
      assigner.assign(isolation_segment, [org])
    end

    it 'updates the organization' do
      expect(org.default_isolation_segment_guid).to eq(nil)

      patch :update_default_isolation_segment, params: { guid: org.guid }.merge(request_body), as: :json

      org.reload
      expect(response.status).to eq(200)
      expect(org.default_isolation_segment_guid).to eq(isolation_segment.guid)
      expect(parsed_body['data']['guid']).to eq(isolation_segment.guid)
    end

    context 'when the requested data is null' do
      let(:request_body) do
        {
          data: nil
        }
      end

      before do
        org.default_isolation_segment_guid = 'prev-iso-seg'
      end
      it 'should update the org default iso seg guid to null' do
        expect(org.default_isolation_segment_guid).to eq('prev-iso-seg')

        patch :update_default_isolation_segment, params: { guid: org.guid }.merge(request_body), as: :json

        org.reload
        expect(response.status).to eq(200)
        expect(org.default_isolation_segment_guid).to be_nil
        expect(parsed_body['data']).to be_nil
      end
    end

    context 'when the requested isolation segment has not been entitled to the org' do
      let(:org2) { VCAP::CloudController::Organization.make }
      before do
        allow_user_read_access_for(user, orgs: [org2])
      end

      it 'throws an UnprocessableEntity error ' do
        patch :update_default_isolation_segment, params: { guid: org2.guid }.merge(request_body), as: :json

        org.reload
        error_string = "Unable to assign isolation segment with guid '#{isolation_segment.guid}'. Ensure it has been entitled to the organization."

        expect(response.status).to eq(422)
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include(error_string)
      end
    end

    context 'when the organization does not exist' do
      it 'throws ResourceNotFound error' do
        patch :update_default_isolation_segment, params: { guid: 'cest-ne-pas-un-org' }.merge(request_body), as: :json

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Organization not found'
      end
    end

    context 'when the isolation segment does not exist' do
      let(:request_body) do
        {
          data: { guid: 'garbage-guid' }
        }
      end

      it 'throws UnprocessableEntity error' do
        patch :update_default_isolation_segment, params: { guid: org.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include "Unable to assign isolation segment with guid 'garbage-guid'. Ensure it has been entitled to the organization."
      end
    end

    context 'when the assignment fails' do
      before do
        allow_any_instance_of(VCAP::CloudController::SetDefaultIsolationSegment).to receive(:set).and_raise(
          VCAP::CloudController::SetDefaultIsolationSegment::Error.new('bad thing happened!'))
      end

      it 'returns 422' do
        patch :update_default_isolation_segment, params: { guid: org.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('bad thing happened!')
      end
    end

    context 'when the request provides invalid data' do
      let(:request_body) do
        {
          data: { guid: 123 }
        }
      end

      it 'returns 422' do
        patch :update_default_isolation_segment, params: { guid: org.guid }.merge(request_body), as: :json

        expect(response.status).to eq(422)
        expect(response.body).to include('UnprocessableEntity')
        expect(response.body).to include('123 must be a string')
      end
    end

    context 'permissions' do
      context 'when the user does not have permissions to read from organization' do
        before do
          allow_user_read_access_for(user)
        end

        it 'throws ResourceNotFound error' do
          patch :update_default_isolation_segment, params: { guid: org.guid }.merge(request_body), as: :json

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Organization not found'
        end
      end

      context 'when the user is not an admin or org manager for that org' do
        before do
          allow_user_read_access_for(user, orgs: [org])
          set_current_user(user, { admin: false })
        end

        it 'throws Unauthorized error' do
          patch :update_default_isolation_segment, params: { guid: org.guid }.merge(request_body), as: :json

          expect(org.managers).not_to include(user)
          expect(user.admin).to be_falsey
          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end

    context 'when the org is suspended' do
      let(:org) { VCAP::CloudController::Organization.make(name: 'Water') }
      let(:space) { VCAP::CloudController::Space.make(organization: org) }
      before do
        org.update(status: VCAP::CloudController::Organization::SUSPENDED)
      end
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 403,
            'global_auditor' => 403,
            'space_developer' => 403,
            'space_manager' => 403,
            'space_auditor' => 403,
            'org_manager' => 403,
            'org_auditor' => 403,
            'org_billing_manager' => 403,
          }
        end
        let(:api_call) { lambda { patch :update_default_isolation_segment, params: { guid: org.guid }.merge(request_body), as: :json } }
      end
    end
  end

  describe '#update' do
    let(:org) { VCAP::CloudController::Organization.make(name: 'Water') }
    let(:labels) do
      {
        fruit: 'pineapple',
        truck: 'mazda5'
      }
    end
    let(:annotations) do
      {
        potato: 'yellow',
        beet: 'golden',
      }
    end
    let(:space) { VCAP::CloudController::Space.make(organization: org) }
    let(:user) { VCAP::CloudController::User.make }
    let(:request_body) do
      {
        name: 'Fire',
        metadata: {
          labels: {
            fruit: 'passionfruit'
          },
          annotations: {
            potato: 'idaho'
          }
        }
      }
    end
    before do
      VCAP::CloudController::LabelsUpdate.update(org, labels, VCAP::CloudController::OrganizationLabelModel)
      VCAP::CloudController::AnnotationsUpdate.update(org, annotations, VCAP::CloudController::OrganizationAnnotationModel)
    end

    context 'when the user is an admin' do
      before do
        set_current_user(user, { admin: true })
      end

      it 'updates the organization' do
        patch :update, params: { guid: org.guid }.merge(request_body), as: :json

        expect(response.status).to eq(200)
        expect(parsed_body['name']).to eq('Fire')
        expect(parsed_body['guid']).to eq(org.guid)
        expect(parsed_body['metadata']['labels']).to eq({ 'fruit' => 'passionfruit', 'truck' => 'mazda5' })
        expect(parsed_body['metadata']['annotations']).to eq({ 'potato' => 'idaho', 'beet' => 'golden' })

        org.reload
        expect(org.name).to eq('Fire')
        expect(org).to have_labels({ key: 'fruit', value: 'passionfruit' }, { key: 'truck', value: 'mazda5' })
        expect(org).to have_annotations({ key: 'potato', value: 'idaho' }, { key: 'beet', value: 'golden' })
      end

      it 'deletes annotations' do
        request_body = {
          metadata: {
            annotations: {
              potato: nil
            }
          }
        }

        patch :update, params: { guid: org.guid }.merge(request_body), as: :json

        expect(response.status).to eq(200)
        expect(parsed_body['metadata']['annotations']).to eq({ 'beet' => 'golden' })

        org.reload
        expect(org).to have_annotations({ key: 'beet', value: 'golden' })
      end

      context 'when a label is deleted' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                fruit: nil
              }
            }
          }
        end

        it 'succeeds' do
          patch :update, params: { guid: org.guid }.merge(request_body), as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['labels']).to eq({ 'truck' => 'mazda5' })

          org.reload
          expect(org).to have_labels({ key: 'truck', value: 'mazda5' })
        end
      end

      context 'when an empty request is sent' do
        let(:request_body) do
          {}
        end

        it 'succeeds' do
          patch :update, params: { guid: org.guid }.merge(request_body), as: :json
          expect(response.status).to eq(200)
          org.reload
          expect(org.name).to eq('Water')
          expect(parsed_body['name']).to eq('Water')
          expect(parsed_body['guid']).to eq(org.guid)
        end
      end

      context 'when there is a message validation failure' do
        let(:request_body) do
          {
            name: ''
          }
        end

        it 'displays an informative error' do
          patch :update, params: { guid: org.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message('Name is too short (minimum is 1 character)')
        end
      end

      context 'when there is a valid label (but no name)' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                key: 'value'
              }
            }
          }
        end

        it 'updates the metadata' do
          patch :update, params: { guid: org.guid }.merge(request_body), as: :json
          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['labels']['key']).to eq 'value'
        end
      end

      context 'when there is an invalid label' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                'cloudfoundry.org/label': 'value'
              }
            }
          }
        end

        it 'displays an informative error' do
          patch :update, params: { guid: org.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/label [\w\s]+ error/)
        end
      end

      context 'when there are too many annotations' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                radish: 'daikon',
                potato: 'idaho'
              }
            }
          }
        end

        before do
          VCAP::CloudController::Config.config.set(:max_annotations_per_resource, 2)
        end

        it 'fails with a 422' do
          patch :update, params: { guid: org.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/exceed maximum of 2/)
        end
      end
    end

    describe 'authorization' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 403,
            'global_auditor' => 403,
            'space_developer' => 403,
            'space_manager' => 403,
            'space_auditor' => 403,
            'org_manager' => 200,
            'org_auditor' => 403,
            'org_billing_manager' => 403,
          }
        end
        let(:api_call) { lambda { patch :update, params: { guid: org.guid }.merge(request_body), as: :json } }
      end

      context 'when the org is suspended' do
        before do
          org.update(status: VCAP::CloudController::Organization::SUSPENDED)
        end
        it_behaves_like 'permissions endpoint' do
          let(:roles_to_http_responses) do
            {
              'admin' => 200,
              'admin_read_only' => 403,
              'global_auditor' => 403,
              'space_developer' => 403,
              'space_manager' => 403,
              'space_auditor' => 403,
              'org_manager' => 403,
              'org_auditor' => 403,
              'org_billing_manager' => 403,
            }
          end
          let(:api_call) { lambda { patch :update, params: { guid: org.guid }.merge(request_body), as: :json } }
        end
      end
    end

    context 'when the org does not exist' do
      before do
        set_current_user(user, { admin: true })
        allow_user_read_access_for(user, orgs: [org])
      end

      it 'throws ResourceNotFound error' do
        patch :update, params: { guid: 'not-a-real-guid' }.merge(request_body), as: :json

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Organization not found'
      end
    end
  end
end
