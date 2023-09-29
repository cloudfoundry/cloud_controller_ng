require 'rails_helper'
require 'isolation_segment_assign'

## NOTICE: Prefer request specs over controller specs as per ADR #0003 ##

RSpec.describe IsolationSegmentsController, type: :controller do
  let(:user) { set_current_user(VCAP::CloudController::User.make) }
  let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
  let(:org1) { VCAP::CloudController::Organization.make }
  let(:org2) { VCAP::CloudController::Organization.make }
  let(:org3) { VCAP::CloudController::Organization.make }
  let(:space) { VCAP::CloudController::Space.make(organization: org1) }

  let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

  describe '#relationships_orgs' do
    context 'when the segment has not been assigned to any orgs' do
      context 'when the user has global read access' do
        before do
          allow_user_global_read_access(user)
        end

        it 'returns an empty list' do
          get :relationships_orgs, params: { guid: isolation_segment_model.guid }, as: :json
          expect(response).to have_http_status :ok

          org_guids = parsed_body['data'].pluck('guid')

          expect(org_guids).to be_empty
        end
      end

      context 'when the user does not have global read access' do
        before do
          set_current_user_as_role(user: user, role: 'org_user', org: org1)
        end

        it 'returns a 404' do
          get :relationships_orgs, params: { guid: isolation_segment_model.guid }, as: :json
          expect(response).to have_http_status :not_found
        end
      end
    end

    context 'when the segment has been assigned to orgs' do
      before do
        assigner.assign(isolation_segment_model, [org1, org2])
      end

      context 'when the user has global read access' do
        before do
          allow_user_global_read_access(user)
        end

        it 'returns the org guids for all allowed organizations' do
          get :relationships_orgs, params: { guid: isolation_segment_model.guid }, as: :json
          expect(response).to have_http_status :ok

          org_guids = parsed_body['data'].pluck('guid')
          expect(org_guids).to include(org1.guid, org2.guid)
        end
      end

      context 'when the user does not have global read access' do
        before do
          set_current_user_as_role(user: user, role: 'org_user', org: org3)
        end

        it 'returns a 404' do
          get :relationships_orgs, params: { guid: isolation_segment_model.guid }, as: :json
          expect(response).to have_http_status :not_found
        end

        context "when the user is an org user for an org in the isolation segment's allowed list" do
          before do
            set_current_user_as_role(user: user, role: 'org_user', org: org1)
          end

          it 'returns the org guids for only those allowed organizations to which the user has access' do
            get :relationships_orgs, params: { guid: isolation_segment_model.guid }, as: :json
            expect(response).to have_http_status :ok

            org_guids = parsed_body['data'].pluck('guid')
            expect(org_guids).to contain_exactly(org1.guid)
          end
        end
      end
    end
  end

  describe '#relationships_spaces' do
    let(:space1) { VCAP::CloudController::Space.make(organization: org1) }
    let(:space2) { VCAP::CloudController::Space.make(organization: org2) }
    let(:space3) { VCAP::CloudController::Space.make(organization: org1) }

    context 'when the segment has not been associated with spaces' do
      context 'when the user does not have read access for isolation segment' do
        before do
          set_current_user_as_role(user: user, role: 'org_user', org: org1)
        end

        it 'returns a 404' do
          get :relationships_spaces, params: { guid: isolation_segment_model.guid }, as: :json
          expect(response).to have_http_status :not_found
        end
      end
    end

    context 'when the segment has been associated with spaces' do
      before do
        assigner.assign(isolation_segment_model, [org1, org2])
        isolation_segment_model.add_space(space1)
        isolation_segment_model.add_space(space2)
        isolation_segment_model.add_space(space3)
      end

      context 'when the user has read access for isolation segment' do
        before do
          set_current_user_as_role(user: user, role: 'space_auditor', space: space1, org: space1.organization)
          set_current_user_as_role(user: user, role: 'space_auditor', space: space2, org: space2.organization)
          set_current_user_as_role(user: user, role: 'space_auditor', space: space3, org: space3.organization)
        end

        it 'returns the guids of all associated spaces' do
          get :relationships_spaces, params: { guid: isolation_segment_model.guid }, as: :json
          expect(response).to have_http_status :ok

          guids = parsed_body['data'].pluck('guid')
          expect(guids).to contain_exactly(space1.guid, space2.guid, space3.guid)
        end
      end

      context "and the user has read access for a subset of the org's spaces" do
        before do
          set_current_user_as_role(user: user, role: 'space_auditor', space: space1, org: space1.organization)
          set_current_user_as_role(user: user, role: 'space_auditor', space: space3, org: space3.organization)
        end

        it 'returns the guids of only the allowed spaces' do
          get :relationships_spaces, params: { guid: isolation_segment_model.guid }, as: :json
          expect(response).to have_http_status :ok

          guids = parsed_body['data'].pluck('guid')
          expect(guids).to contain_exactly(space1.guid, space3.guid)
        end
      end
    end
  end

  describe '#assign_allowed_organizations' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:org1) { VCAP::CloudController::Organization.make }
    let(:org2) { VCAP::CloudController::Organization.make }

    let(:request_body) do
      {
        data: [
          { guid: org1.guid }
        ]
      }
    end

    context 'when the user is admin' do
      before do
        set_current_user_as_admin
      end

      it 'assigns the isolation segment to the org' do
        post :assign_allowed_organizations, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :ok
        expect(parsed_body['data'][0]['guid']).to eq(org1.guid)
        expect(isolation_segment_model.organizations).to contain_exactly(org1)
      end

      it 'assigns multiple organizations to the isolation segment' do
        request_body[:data] << { guid: org2.guid }
        post :assign_allowed_organizations, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json

        expect(response).to have_http_status :ok

        entitled_guids = []
        parsed_body['data'].each do |item|
          entitled_guids << item['guid']
        end

        expect(entitled_guids).to contain_exactly(org1.guid, org2.guid)

        org1.reload
        org2.reload
        expect(isolation_segment_model.organizations).to contain_exactly(org1, org2)
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404' do
          post :assign_allowed_organizations, params: { guid: 'some-guid', org_guid: org1.guid }, as: :json
          expect(response).to have_http_status :not_found
        end
      end

      context 'when the request is malformed' do
        let(:request_body) do
          {
            bork: 'some-name'
          }
        end

        it 'returns a 422' do
          post :assign_allowed_organizations, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json
          expect(response).to have_http_status :unprocessable_entity
        end
      end

      context 'when the request contains an org that does not exist' do
        let(:request_body) do
          {
            data: [
              { guid: org1.guid },
              { guid: 'bogus-guid' }
            ]
          }
        end

        it 'does not assign any of the valid orgs and returns a 404' do
          post :assign_allowed_organizations, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json
          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include 'bogus-guid'
          expect(response.body).not_to include org1.guid

          expect(isolation_segment_model.organizations).to be_empty
          expect(org1.default_isolation_segment_model).to be_nil
        end
      end

      context 'when the isolation segment has already been assigned to the specified organization' do
        before do
          assigner.assign(isolation_segment_model, [org1])
        end

        it 'returns a 200 and leaves the existing assignment intact' do
          post :assign_allowed_organizations, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :ok

          expect(isolation_segment_model.organizations).to include(org1)
        end
      end
    end

    context 'when the user is not an admin' do
      before do
        allow_user_write_access(user, space:)
      end

      it 'returns a 403' do
        post :assign_allowed_organizations, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json
        expect(response).to have_http_status :forbidden
      end
    end
  end

  describe '#unassign_allowed_organization' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:org_2) { VCAP::CloudController::Organization.make }

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      it 'unassigns Isolation Segments from the org' do
        post :unassign_allowed_organization, params: { guid: isolation_segment_model.guid, org_guid: org.guid }, as: :json
        expect(response).to have_http_status :no_content
      end

      context 'when a request body is supplied' do
        let(:request_body) do
          {
            data: [
              { guid: org2.guid }
            ]
          }
        end

        before do
          assigner.assign(isolation_segment_model, [org2])
        end

        it 'ignores the body' do
          post :unassign_allowed_organization, params: { guid: isolation_segment_model.guid, org_guid: org.guid }.merge(request_body), as: :json
          expect(response).to have_http_status :no_content
          expect(isolation_segment_model.organizations).to include(org2)
        end
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404' do
          post :unassign_allowed_organization, params: { guid: 'bad-guid', org_guid: org.guid }, as: :json
          expect(response).to have_http_status :not_found
        end
      end

      context 'when the organization does not exist' do
        it 'returns a 404' do
          post :unassign_allowed_organization, params: { guid: isolation_segment_model.guid, org_guid: 'bad-guid' }, as: :json
          expect(response).to have_http_status :not_found
        end
      end
    end

    context 'when the user is not an admin' do
      before do
        allow_user_write_access(user, space:)
      end

      it 'returns a 403' do
        post :unassign_allowed_organization, params: { guid: isolation_segment_model.guid, org_guid: org.guid }, as: :json
        expect(response).to have_http_status :forbidden
      end
    end
  end

  describe '#create' do
    let(:request_body) do
      {
        name: 'some-name'
      }
    end

    context 'when the user is admin' do
      before do
        set_current_user_as_admin
      end

      it 'returns a 201 Created and the isolation segment' do
        post :create, params: request_body

        expect(response).to have_http_status :created

        isolation_segment_model = VCAP::CloudController::IsolationSegmentModel.last
        expect(isolation_segment_model.name).to eq 'some-name'
      end

      context 'when the request is malformed' do
        let(:request_body) do
          {
            bork: 'some-name'
          }
        end

        it 'returns a 422' do
          post :create, body: request_body
          expect(response).to have_http_status :unprocessable_entity
        end
      end

      context 'when the requested name is a duplicate' do
        it 'returns a 422' do
          VCAP::CloudController::IsolationSegmentModel.make(name: 'some-name')
          post :create, params: request_body

          expect(response).to have_http_status :unprocessable_entity
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space:)
      end

      it 'returns a 403' do
        post :create, params: request_body
        expect(response).to have_http_status :forbidden
      end
    end
  end

  describe '#show' do
    let!(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'some-name') }

    context 'when the user has global read access' do
      before do
        allow_user_global_read_access(user)
      end

      context 'when the isolation segment has been created' do
        it 'returns a 200 and the correct isolation segment' do
          get :show, params: { guid: isolation_segment.guid }, as: :json

          expect(response).to have_http_status :ok
          expect(parsed_body['guid']).to eq(isolation_segment.guid)
          expect(parsed_body['name']).to eq(isolation_segment.name)
          expect(parsed_body['links']['self']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}")
          expect(parsed_body['links']['organizations']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}/organizations")
        end
      end

      context 'when the isolation segment has not been created' do
        it 'returns a 404' do
          get :show, params: { guid: 'noexistent-guid' }, as: :json

          expect(response).to have_http_status :not_found
        end
      end
    end

    context 'when the user does not have global read access' do
      context "and the user is an org user for an org in the isolation segment's allowed list" do
        before do
          set_current_user_as_role(user: user, role: 'org_user', org: org1)
          assigner.assign(isolation_segment, [org1])
        end

        it 'allows the user to see the isolation segment' do
          get :show, params: { guid: isolation_segment.guid }, as: :json

          expect(response).to have_http_status :ok
          expect(parsed_body['guid']).to eq(isolation_segment.guid)
          expect(parsed_body['name']).to eq(isolation_segment.name)
        end

        context 'and the user is registered to a space' do
          before do
            set_current_user_as_role(user: user, role: 'space_auditor', space: space, org: space.organization)
          end

          context 'and the space is associated to an isolation segment' do
            before do
              isolation_segment.add_space(space)
            end

            it 'allows the user to see the isolation segment' do
              get :show, params: { guid: isolation_segment.guid }, as: :json

              expect(response).to have_http_status :ok
              expect(parsed_body['guid']).to eq(isolation_segment.guid)
              expect(parsed_body['name']).to eq(isolation_segment.name)
              expect(parsed_body['links']['self']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}")
              expect(parsed_body['links']['organizations']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}/organizations")
            end
          end
        end
      end
    end
  end

  describe '#index' do
    let(:space) { VCAP::CloudController::Space.make }

    before do
      set_current_user_as_role(user: user, role: 'space_auditor', space: space, org: space.organization)
    end

    context 'when using query params' do
      before do
        allow_user_global_read_access(user)
      end

      context 'when invalid' do
        context 'with invalid param format' do
          it 'returns a 400' do
            get :index, params: { order_by: '^=%' }, as: :json

            expect(response).to have_http_status :bad_request
            expect(response.body).to include 'BadQueryParameter'
            expect(response.body).to include("Order by can only be: 'created_at', 'updated_at', 'name'")
          end
        end

        context 'with a parameter value outside the allowed values' do
          it 'returns a 400 and a list of allowed values' do
            get :index, params: { order_by: 'invalid' }, as: :json

            expect(response).to have_http_status :bad_request
            expect(response.body).to include 'BadQueryParameter'
            expect(response.body).to include("Order by can only be: 'created_at', 'updated_at', 'name'")
          end
        end

        context 'with an unknown query param' do
          it 'returns 400 and a list of the unknown params' do
            get :index, params: { meow: 'woof', kaplow: 'zoom' }, as: :json

            expect(response).to have_http_status :bad_request
            expect(response.body).to include 'BadQueryParameter'
            expect(response.body).to include('Unknown query parameter(s):')
            expect(response.body).to include('meow')
            expect(response.body).to include('kaplow')
          end
        end

        context 'with invalid pagination params' do
          it 'returns 400 and the allowed param range' do
            get :index, params: { per_page: 99_999_999_999_999_999 }, as: :json

            expect(response).to have_http_status :bad_request
            expect(response.body).to include 'BadQueryParameter'
            expect(response.body).to include 'Per page must be between'
          end
        end
      end

      context 'when valid' do
        let!(:isolation_segment_a) { VCAP::CloudController::IsolationSegmentModel.make(name: 'a-segment') }
        let!(:isolation_segment_b) { VCAP::CloudController::IsolationSegmentModel.make(name: 'b-segment') }

        it 'returns a 200 and a list of the existing isolation segments' do
          get :index, params: { order_by: 'name' }, as: :json

          expect(response).to have_http_status(:ok)
          response_names = parsed_body['resources'].pluck('name')
          expect(response_names.length).to eq(3)
          expect(response_names).to eq(%w[a-segment b-segment shared])
        end
      end
    end
  end

  describe '#update' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make(name: 'orig-name') }
    let(:new_name) { 'new-name' }
    let(:request_body) { { name: new_name } }

    context 'when the user is admin' do
      before do
        set_current_user_as_admin
      end

      context 'when the isolation segment exists' do
        it 'returns a 200 and the entity information with the updated name' do
          put :update, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json

          expect(response).to have_http_status :ok
          expect(parsed_body['guid']).to eq(isolation_segment_model.guid)
          expect(parsed_body['name']).to eq(new_name)
          expect(parsed_body['links']['self']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}")
        end

        context 'with a non-unique name' do
          let(:another_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'i_am_unique') }
          let(:request_body) { { name: another_segment.name } }

          it 'returns a 422' do
            put :update, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json

            expect(response).to have_http_status :unprocessable_entity
          end
        end

        context 'with an empty name' do
          let(:another_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'name') }
          let(:request_body) { { name: '' } }

          it 'returns a 422' do
            put :update, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json

            expect(response).to have_http_status :unprocessable_entity
          end
        end

        context 'with an invalid request body' do
          let(:request_body) { { bork: 'some-name' } }

          it 'returns a 422' do
            post :create, params: request_body
            expect(response).to have_http_status :unprocessable_entity
          end
        end
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404' do
          put :update, params: { guid: 'nonexistent-guid' }.merge(request_body), as: :json

          expect(response).to have_http_status :not_found
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space:)
      end

      it 'returns a 403' do
        put :update, params: { guid: isolation_segment_model.guid }.merge(request_body), as: :json
        expect(response).to have_http_status :forbidden
      end
    end
  end

  describe '#destroy' do
    let(:isolation_segment_model1) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:isolation_segment_model2) { VCAP::CloudController::IsolationSegmentModel.make }

    context 'when the user is admin' do
      before do
        set_current_user_as_admin
      end

      context 'when the isolation segment exists' do
        it 'returns a 204 and deletes only the specified isolation segment' do
          delete :destroy, params: { guid: isolation_segment_model1.guid }, as: :json

          expect(response).to have_http_status :no_content
          expect { isolation_segment_model1.reload }.to raise_error(Sequel::Error, 'Record not found')
          expect { isolation_segment_model2.reload }.not_to raise_error
        end

        context 'when the isolation segment is associated to an organization' do
          before do
            allow_any_instance_of(VCAP::CloudController::IsolationSegmentDelete).to receive(:delete).
              and_raise(VCAP::CloudController::IsolationSegmentDelete::AssociationNotEmptyError.new(
                          'Revoke the Organization entitlements for your Isolation Segment.'
                        ))
          end

          it 'returns a 422 UnprocessableEntity error' do
            delete :destroy, params: { guid: isolation_segment_model1.guid }, as: :json

            expect(response).to have_http_status :unprocessable_entity
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Revoke the Organization entitlements for your Isolation Segment.')
          end
        end

        context 'when isolation segment has metadata' do
          let!(:label) { VCAP::CloudController::IsolationSegmentAnnotationModel.make(key_name: 'string', value: 'string2', resource_guid: isolation_segment_model1.guid) }

          it 'returns a 204 and deletes only the specified isolation segment' do
            delete :destroy, params: { guid: isolation_segment_model1.guid }, as: :json

            expect(response).to have_http_status :no_content
            expect(label).not_to exist
          end
        end
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404 not found' do
          delete :destroy, params: { guid: 'nonexistent-guid' }, as: :json

          expect(response).to have_http_status :not_found
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space:)
      end

      it 'returns a 403' do
        delete :destroy, params: { guid: isolation_segment_model1.guid }, as: :json
        expect(response).to have_http_status :forbidden
      end
    end
  end

  describe 'default shared isolation segment' do
    let(:shared_segment) do
      VCAP::CloudController::IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
    end

    let!(:original_name) { shared_segment.name }

    let(:request_body) do
      {
        name: 'some-other-name'
      }
    end

    before do
      set_current_user_as_admin
    end

    it 'cannot be deleted' do
      delete :destroy, params: { guid: shared_segment.guid }, as: :json

      expect(response).to have_http_status :unprocessable_entity
      expect(VCAP::CloudController::IsolationSegmentModel.first(guid: shared_segment.guid).exists?).to be true
    end

    it 'cannot be updated via API' do
      put :update, params: { guid: shared_segment.guid, body: request_body }, as: :json

      expect(response).to have_http_status :unprocessable_entity
      expect(shared_segment.name).to eq(original_name)
    end
  end
end
