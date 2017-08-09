require 'rails_helper'
require 'isolation_segment_assign'

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
      context ' when the user has global read access' do
        before do
          allow_user_global_read_access(user)
        end

        it 'returns an empty list' do
          get :relationships_orgs, guid: isolation_segment_model.guid
          expect(response.status).to eq 200

          org_guids = parsed_body['data'].map { |r| r['guid'] }

          expect(org_guids).to be_empty
        end
      end

      context 'when user does not have global read access' do
        before do
          disallow_user_global_read_access(user)
        end

        it 'returns a 404' do
          get :relationships_orgs, guid: isolation_segment_model.guid
          expect(response.status).to eq 404
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
          get :relationships_orgs, guid: isolation_segment_model.guid
          expect(response.status).to eq 200

          org_guids = parsed_body['data'].map { |r| r['guid'] }
          expect(org_guids).to include(org1.guid, org2.guid)
        end
      end

      context 'when the user does not have global read access' do
        before do
          allow_user_read_access_for(user, orgs: [org3])
        end

        it 'returns a 404' do
          get :relationships_orgs, guid: isolation_segment_model.guid
          expect(response.status).to eq 404
        end

        context "when the user is an org user for an org in the isolation segment's allowed list" do
          before do
            allow_user_read_access_for(user, orgs: [org1])
          end

          it 'returns the org guids for only those allowed organizations to which the user has access' do
            get :relationships_orgs, guid: isolation_segment_model.guid
            expect(response.status).to eq 200

            org_guids = parsed_body['data'].map { |r| r['guid'] }
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
      context 'when the user has read access for isolation segment' do
        before do
          allow_user_read_access_for_isolation_segment(user)
          allow_user_read_access_for(user, spaces: [space1, space2, space3])
        end

        it 'returns an empty list' do
          get :relationships_spaces, guid: isolation_segment_model.guid
          expect(response.status).to eq 200

          guids = parsed_body['data'].map { |r| r['guid'] }

          expect(guids).to be_empty
        end
      end

      context 'when the user does not have read access for isolation segment' do
        before do
          disallow_user_read_access_for_isolation_segment(user)
        end

        it 'returns a 404' do
          get :relationships_spaces, guid: isolation_segment_model.guid
          expect(response.status).to eq 404
        end
      end
    end

    context 'when the segment has been associated with spaces' do
      before do
        assigner.assign(isolation_segment_model, [org1, org2])
        isolation_segment_model.add_space(space1)
        isolation_segment_model.add_space(space2)
        isolation_segment_model.add_space(space3)
        allow_user_read_access_for_isolation_segment(user)
      end

      context 'when the user has read access for isolation segment' do
        before do
          allow_user_read_access_for(user, orgs: [org1], spaces: [space1, space2, space3])
        end

        it 'returns the guids of all associated spaces' do
          get :relationships_spaces, guid: isolation_segment_model.guid
          expect(response.status).to eq 200

          guids = parsed_body['data'].map { |r| r['guid'] }
          expect(guids).to match_array([space1.guid, space2.guid, space3.guid])
        end
      end

      context "and the user has read access for a subset of the org's spaces" do
        before do
          allow_user_read_access_for(user, orgs: [org1], spaces: [space1, space3])
        end

        it 'returns the guids of only the allowed spaces' do
          get :relationships_spaces, guid: isolation_segment_model.guid
          expect(response.status).to eq 200

          guids = parsed_body['data'].map { |r| r['guid'] }
          expect(guids).to match_array([space1.guid, space3.guid])
        end
      end
    end
  end

  describe '#assign_allowed_organizations' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:org1) { VCAP::CloudController::Organization.make }
    let(:org2) { VCAP::CloudController::Organization.make }

    let(:req_body) do
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
        post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body

        expect(response.status).to eq 200
        expect(parsed_body['data'][0]['guid']).to eq(org1.guid)
        expect(isolation_segment_model.organizations).to contain_exactly(org1)
      end

      it 'assigns multiple organizations to the isolation segment' do
        req_body[:data] << { guid: org2.guid }
        post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body

        expect(response.status).to eq 200

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
          post :assign_allowed_organizations, guid: 'some-guid', org_guid: org1.guid
          expect(response.status).to eq 404
        end
      end

      context 'when the request is malformed' do
        let(:req_body) {
          {
            bork: 'some-name',
          }
        }

        it 'returns a 422' do
          post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
          expect(response.status).to eq 422
        end
      end

      context 'when the request contains an org that does not exist' do
        let(:req_body) do
          {
            data: [
              { guid: org1.guid },
              { guid: 'bogus-guid' }
            ]
          }
        end

        it 'does not assign any of the valid orgs and returns a 404' do
          post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
          expect(response.status).to eq 422
          expect(response.body).to include 'bogus-guid'
          expect(response.body).to_not include org1.guid

          expect(isolation_segment_model.organizations).to be_empty
          expect(org1.default_isolation_segment_model).to be_nil
        end
      end

      context 'when the isolation segment has already been assigned to the specified organization' do
        before do
          assigner.assign(isolation_segment_model, [org1])
        end

        it 'returns a 200 and leaves the existing assignment intact' do
          post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body

          expect(response.status).to eq 200

          expect(isolation_segment_model.organizations).to include(org1)
        end
      end
    end

    context 'when the user is not an admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
        expect(response.status).to eq 403
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
        post :unassign_allowed_organization, guid: isolation_segment_model.guid, org_guid: org.guid
        expect(response.status).to eq 204
      end

      context 'when a request body is supplied' do
        let(:req_body) do
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
          post :unassign_allowed_organization, guid: isolation_segment_model.guid, org_guid: org.guid, body: req_body
          expect(response.status).to eq 204
          expect(isolation_segment_model.organizations).to include(org2)
        end
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404' do
          post :unassign_allowed_organization, guid: 'bad-guid', org_guid: org.guid
          expect(response.status).to eq 404
        end
      end

      context 'when the organization does not exist' do
        it 'returns a 404' do
          post :unassign_allowed_organization, guid: isolation_segment_model.guid, org_guid: 'bad-guid'
          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user is not an admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        post :unassign_allowed_organization, guid: isolation_segment_model.guid, org_guid: org.guid
        expect(response.status).to eq 403
      end
    end
  end

  describe '#create' do
    let(:req_body) do
      {
        name: 'some-name',
      }
    end

    context 'when the user is admin' do
      before do
        set_current_user_as_admin
      end

      it 'returns a 201 Created  and the isolation segment' do
        post :create, body: req_body

        expect(response.status).to eq 201

        isolation_segment_model = VCAP::CloudController::IsolationSegmentModel.last
        expect(isolation_segment_model.name).to eq 'some-name'
      end

      context 'when the request is malformed' do
        let(:req_body) {
          {
            bork: 'some-name',
          }
        }
        it 'returns a 422' do
          post :create, body: req_body
          expect(response.status).to eq 422
        end
      end

      context 'when the requested name is a duplicate' do
        it 'returns a 422' do
          VCAP::CloudController::IsolationSegmentModel.make(name: 'some-name')
          post :create, body: req_body

          expect(response.status).to eq 422
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        post :create, body: req_body
        expect(response.status).to eq 403
      end
    end
  end

  describe '#show' do
    let!(:isolation_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'some-name') }

    context 'when the user has global read access' do
      before do
        allow_user_global_read_access(user)
        allow_user_read_access_for_isolation_segment(user)
      end

      context 'when the isolation segment has been created' do
        it 'returns a 200 and the correct isolation segment' do
          get :show, guid: isolation_segment.guid

          expect(response.status).to eq 200
          expect(parsed_body['guid']).to eq(isolation_segment.guid)
          expect(parsed_body['name']).to eq(isolation_segment.name)
          expect(parsed_body['links']['self']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}")
          expect(parsed_body['links']['organizations']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}/organizations")
        end
      end

      context 'when the isolation segment has not been created' do
        it 'returns a 404' do
          get :show, guid: 'noexistent-guid'

          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user does not have global read access' do
      context "and the user is an org user for an org in the isolation segment's allowed list" do
        before do
          allow_user_read_access_for(user, orgs: [org1])
          assigner.assign(isolation_segment, [org1])
          allow_user_read_access_for_isolation_segment(user)
        end

        it 'allows the user to see the isolation segment' do
          get :show, guid: isolation_segment.guid

          expect(response.status).to eq 200
          expect(parsed_body['guid']).to eq(isolation_segment.guid)
          expect(parsed_body['name']).to eq(isolation_segment.name)
        end

        context 'and the user is registered to a space' do
          before do
            allow_user_read_access_for(user, spaces: [space])
          end

          context 'and the space is associated to an isolation segment' do
            before do
              isolation_segment.add_space(space)
            end

            it 'allows the user to see the isolation segment' do
              get :show, guid: isolation_segment.guid

              expect(response.status).to eq 200
              expect(parsed_body['guid']).to eq(isolation_segment.guid)
              expect(parsed_body['name']).to eq(isolation_segment.name)
              expect(parsed_body['links']['self']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}")
              expect(parsed_body['links']['organizations']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment.guid}/organizations")
            end
          end
        end
      end

      context 'and the user is not registered to any space or org associated with the isolation segment' do
        let(:other_space) { VCAP::CloudController::Space.make }

        before do
          allow_user_read_access_for(user, spaces: [other_space])
          disallow_user_read_access_for_isolation_segment(user)
        end

        it 'returns a 404' do
          get :show, guid: isolation_segment.guid

          expect(response.status).to eq 404
        end
      end
    end
  end

  describe '#index' do
    let(:space) { VCAP::CloudController::Space.make }

    before do
      allow_user_read_access_for(user, spaces: [space])
    end

    context 'when using query params' do
      context 'with invalid param format' do
        it 'returns a 400' do
          get :index, order_by: '^=%'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be: 'created_at', 'updated_at'")
        end
      end

      context 'with a parameter value outside the allowed values' do
        it 'returns a 400 and a list of allowed values' do
          get :index, order_by: 'name'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be: 'created_at', 'updated_at'")
        end
      end

      context 'with an unknown query param' do
        it 'returns 400 and a list of the unknown params' do
          get :index, meow: 'woof', kaplow: 'zoom'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Unknown query parameter(s): 'meow', 'kaplow'")
        end
      end

      context 'with invalid pagination params' do
        it 'returns 400 and the allowed param range' do
          get :index, per_page: 99999999999999999

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include 'Per page must be between'
        end
      end
    end

    context 'when the user is not an admin' do
      let!(:isolation_segment1) { VCAP::CloudController::IsolationSegmentModel.make }
      let!(:isolation_segment2) { VCAP::CloudController::IsolationSegmentModel.make }
      let!(:isolation_segment3) { VCAP::CloudController::IsolationSegmentModel.make }
      let(:org1) { VCAP::CloudController::Organization.make }
      let(:org2) { VCAP::CloudController::Organization.make }

      context 'and the user is registered to one or more orgs' do
        before do
          allow_user_read_access_for(user, orgs: [org1, org2])
        end

        context 'and the org is associated with an isolation segment' do
          before do
            assigner.assign(isolation_segment1, [org1])
            assigner.assign(isolation_segment2, [org1])
          end

          it 'allows the user to see only those isolation segments associated with their orgs' do
            get :index

            expect(response.status).to eq 200

            response_guids = parsed_body['resources'].map { |r| r['guid'] }
            expect(response_guids).to include(isolation_segment1.guid)
            expect(response_guids).to include(isolation_segment2.guid)
            expect(response_guids).to_not include(isolation_segment3.guid)
          end
        end
      end
    end

    context 'when the user has global read access' do
      before do
        allow_user_global_read_access(user)
      end

      context 'when isolation segments have been created' do
        let!(:isolation_segment1) { VCAP::CloudController::IsolationSegmentModel.make(name: 'segment1') }
        let!(:isolation_segment2) { VCAP::CloudController::IsolationSegmentModel.make(name: 'segment2') }

        it 'returns a 200 and a list of the existing isolation segments' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids.length).to eq(3)
          expect(response_guids).to include(VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID, isolation_segment1.guid, isolation_segment2.guid)
        end
      end

      context 'when no isolation segments have been created' do
        it 'returns a 200 and the seeded isolation segment' do
          get :index

          response_guids = parsed_body['resources'].map { |r| r['guid'] }
          expect(response.status).to eq(200)
          expect(response_guids.length).to eq(1)
          expect(response_guids).to include(VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
        end
      end
    end
  end

  describe '#update' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make(name: 'orig-name') }
    let(:new_name) { 'new-name' }
    let(:req_body) { { name: new_name } }

    context 'when the user is admin' do
      before do
        set_current_user_as_admin
      end

      context 'when the isolation segment exists' do
        it 'returns a 200 and the entity information with the updated name' do
          put :update, guid: isolation_segment_model.guid, body: req_body

          expect(response.status).to eq 200
          expect(parsed_body['guid']).to eq(isolation_segment_model.guid)
          expect(parsed_body['name']).to eq(new_name)
          expect(parsed_body['links']['self']['href']).to eq("#{link_prefix}/v3/isolation_segments/#{isolation_segment_model.guid}")
        end

        context 'with a non-unique name' do
          let(:another_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'i_am_unique') }
          let(:req_body) { { name: another_segment.name } }

          it 'returns a 422' do
            put :update, guid: isolation_segment_model.guid, body: req_body

            expect(response.status).to eq 422
          end
        end

        context 'with an empty name' do
          let(:another_segment) { VCAP::CloudController::IsolationSegmentModel.make(name: 'name') }
          let(:req_body) { { name: '' } }

          it 'returns a 422' do
            put :update, guid: isolation_segment_model.guid, body: req_body

            expect(response.status).to eq 422
          end
        end

        context 'with an invalid request body' do
          let(:req_body) { { bork: 'some-name' } }

          it 'returns a 422' do
            post :create, body: req_body
            expect(response.status).to eq 422
          end
        end
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404' do
          put :update, guid: 'nonexistent-guid', body: req_body

          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        put :update, guid: isolation_segment_model.guid, body: req_body
        expect(response.status).to eq 403
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
          delete :destroy, guid: isolation_segment_model1.guid

          expect(response.status).to eq 204
          expect { isolation_segment_model1.reload }.to raise_error(Sequel::Error, 'Record not found')
          expect { isolation_segment_model2.reload }.to_not raise_error
        end

        context 'when the isolation segment is associated to an organization' do
          before do
            allow_any_instance_of(VCAP::CloudController::IsolationSegmentDelete).to receive(:delete).
              and_raise(VCAP::CloudController::IsolationSegmentDelete::AssociationNotEmptyError.new(
                          'Revoke the Organization entitlements for your Isolation Segment.'))
          end

          it 'returns a 422 UnprocessableEntity error' do
            delete :destroy, guid: isolation_segment_model1.guid

            expect(response.status).to eq 422
            expect(response.body).to include 'UnprocessableEntity'
            expect(response.body).to include('Revoke the Organization entitlements for your Isolation Segment.')
          end
        end
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404 not found' do
          delete :destroy, guid: 'nonexistent-guid'

          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user is not admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        delete :destroy, guid: isolation_segment_model1.guid
        expect(response.status).to eq 403
      end
    end
  end

  describe 'default shared isolation segment' do
    let(:shared_segment) do
      VCAP::CloudController::IsolationSegmentModel.first(guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID)
    end

    let!(:original_name) { shared_segment.name }

    let(:req_body) do
      {
        name: 'some-other-name',
      }
    end

    before do
      set_current_user_as_admin
    end

    it 'cannot be deleted' do
      delete :destroy, guid: shared_segment.guid

      expect(response.status).to eq 422
      expect(VCAP::CloudController::IsolationSegmentModel.first(guid: shared_segment.guid).exists?).to be true
    end

    it 'cannot be updated via API' do
      put :update, guid: shared_segment.guid, body: req_body

      expect(response.status).to eq 422
      expect(shared_segment.name).to eq(original_name)
    end
  end
end
