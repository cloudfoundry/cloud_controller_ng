require 'rails_helper'

RSpec.describe IsolationSegmentsController, type: :controller do
  let(:user) { set_current_user(VCAP::CloudController::User.make) }
  let(:space) { VCAP::CloudController::Space.make }

  describe '#relationships_orgs' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:org1) { VCAP::CloudController::Organization.make }
    let(:org2) { VCAP::CloudController::Organization.make }

    context 'when user is not an admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        get :relationships_orgs, guid: isolation_segment_model.guid
        expect(response.status).to eq 403
      end
    end

    context ' when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      it 'returns an empty list' do
        get :relationships_orgs, guid: isolation_segment_model.guid
        expect(response.status).to eq 200

        org_guids = parsed_body['data'].map { |r| r['guid'] }

        expect(org_guids).to be_empty
      end

      context 'when the segment has been assigned to orgs' do
        before do
          isolation_segment_model.add_organization(org1)
          isolation_segment_model.add_organization(org2)
        end

        it 'returns the org guids' do
          get :relationships_orgs, guid: isolation_segment_model.guid
          expect(response.status).to eq 200

          org_guids = parsed_body['data'].map { |r| r['guid'] }
          expect(org_guids).to include(org1.guid, org2.guid)
        end
      end
    end
  end

  describe '#relationships_spaces' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:space1) { VCAP::CloudController::Space.make }
    let(:space2) { VCAP::CloudController::Space.make }

    context 'when user is not an admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        get :relationships_spaces, guid: isolation_segment_model.guid
        expect(response.status).to eq 403
      end
    end

    context ' when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      it 'returns an empty list' do
        get :relationships_spaces, guid: isolation_segment_model.guid
        expect(response.status).to eq 200

        guids = parsed_body['data'].map { |r| r['guid'] }

        expect(guids).to be_empty
      end

      context 'when the segment has been associated with spaces' do
        before do
          isolation_segment_model.add_space(space1)
          isolation_segment_model.add_space(space2)
        end

        it 'returns the org guids' do
          get :relationships_spaces, guid: isolation_segment_model.guid
          expect(response.status).to eq 200

          guids = parsed_body['data'].map { |r| r['guid'] }
          expect(guids).to eq([space1.guid, space2.guid])
        end
      end
    end
  end

  describe '#assign_allowed_organizations' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:org_2) { VCAP::CloudController::Organization.make }

    let(:req_body) do
      {
        data: [
          { guid: org.guid }
        ]
      }
    end

    context 'when the user is admin' do
      before do
        set_current_user_as_admin
      end

      it 'assigns the isolation segment to the org' do
        post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body

        expect(response.status).to eq 201

        expect(parsed_body['guid']).to eq(isolation_segment_model.guid)

        expect(isolation_segment_model.organizations).to include(org)
      end

      it 'assigns multiple organizations to the isolation segment' do
        req_body[:data] << { guid: org_2.guid }
        post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body

        expect(response.status).to eq 201

        expect(parsed_body['guid']).to eq(isolation_segment_model.guid)

        # need to reload the orgs because the default isolation segment get set
        # This also means that the updated at time is on our ors
        org.reload
        org_2.reload
        expect(isolation_segment_model.organizations).to include(org, org_2)
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404' do
          post :assign_allowed_organizations, guid: 'some-guid', org_guid: org.guid
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
              { guid: org.guid },
              { guid: 'bogus-guid' }
            ]
          }
        end

        it 'does not assign any of the valid orgs and returns a 400' do
          post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
          expect(response.status).to eq 400

          expect(isolation_segment_model.organizations).to be_empty
          expect(org.isolation_segment_model).to be_nil
        end
      end

      context 'when the organization does not exist' do
        let(:req_body) do
          {
            data: [
              { guid: 'bogus-guid' }
            ]
          }
        end

        it 'returns a 400' do
          post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
          expect(response.status).to eq 400
        end
      end

      context 'when the isolation segment has already been assigned to the specified organization' do
        before do
          isolation_segment_model.add_organization(org)
        end

        it 'returns a 201 and leaves the existing assignment intact' do
          post :assign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body

          expect(response.status).to eq 201

          expect(isolation_segment_model.organizations).to include(org)
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

  describe '#unassign_allowed_organizations' do
    let(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:org_2) { VCAP::CloudController::Organization.make }

    let(:req_body) do
      {
        data: [
          { guid: org.guid }
        ]
      }
    end

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      context 'and no orgs have been assigned to the isoilation segment' do
        it 'removes the org from the isolation segment' do
          post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
          expect(response.status).to eq 204
        end
      end

      context 'and an org has been assigned to the isolation segment' do
        before do
          isolation_segment_model.add_organization(org)
        end

        it 'removes the org from the isolation segment' do
          post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
          expect(response.status).to eq 204

          isolation_segment_model.reload
          org.reload
          expect(isolation_segment_model.organizations).to be_empty
          expect(org.isolation_segment_models).to be_empty
          expect(org.isolation_segment_model).to be_nil
        end

        it 'removes all passsed orgs in the request' do
          req_body[:data] << { guid: org_2.guid }
          post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
          expect(response.status).to eq 204

          isolation_segment_model.reload
          expect(isolation_segment_model.organizations).to be_empty
        end

        context 'when there are multiple isolation segmetns in an organizations allowed list' do
          before do
            isolation_segment_model_2 = VCAP::CloudController::IsolationSegmentModel.make
            isolation_segment_model_2.add_organization(org)
          end

          it 'cannot remove the default isolation segment' do
            post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
            expect(response.status).to eq 400
          end

          context 'and we remove an isolation_segment that is not the default' do
            let(:req_body) do
              {
                data: [
                  { guid: org_2.guid }
                ]
              }
            end

            it 'succeeds' do
              post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
              expect(response.status).to eq 204
            end
          end
        end

        context 'and a space beloning to the org is assinged the isolation segment' do
          before do
            space = VCAP::CloudController::Space.make(organization: org)
            isolation_segment_model.add_space(space)
          end

          it 'returns a 400' do
            post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
            expect(response.status).to eq 400
          end
        end

        context 'and an organization in the request body does not exist' do
          let(:req_body) do
            {
              data: [
                { guid: 'bad-guid' }
              ]
            }
          end

          it 'fails with a 400' do
            post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
            expect(response.status).to eq 400
          end

          it 'does not remove the valid assignments from the request body' do
            req_body[:data] << { guid: org.guid }
            post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
            expect(response.status).to eq 400

            isolation_segment_model.reload
            org.reload
            expect(isolation_segment_model.organizations).to eq([org])
            expect(org.isolation_segment_models).to eq([isolation_segment_model])
            expect(org.isolation_segment_model).to eq(isolation_segment_model)
          end
        end
      end

      context 'when the request is malformed' do
        let(:req_body) {
          {
            bork: 'some-name',
          }
        }

        it 'returns a 422' do
          post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
          expect(response.status).to eq 422
        end
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404' do
          post :unassign_allowed_organizations, guid: 'bad-guid', body: req_body
          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user is not an admin' do
      before do
        allow_user_write_access(user, space: space)
      end

      it 'returns a 403' do
        post :unassign_allowed_organizations, guid: isolation_segment_model.guid, body: req_body
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

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      context 'when the isolation segment has been created' do
        it 'returns a 200 and the correct isolation segment' do
          get :show, guid: isolation_segment.guid

          expect(response.status).to eq 200
          expect(parsed_body['guid']).to eq(isolation_segment.guid)
          expect(parsed_body['name']).to eq(isolation_segment.name)
        end
      end

      context 'when the isolation segment has not been created' do
        it 'returns a 404' do
          get :show, guid: 'noexistent-guid'

          expect(response.status).to eq 404
        end
      end
    end

    context 'when the user is not an admin' do
      context 'and the user is a organization developer' do
      end

      context 'and the user is registered to a space' do
        before do
          allow_user_read_access(user, space: space)
          stub_readable_space_guids_for(user, space)
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
          end
        end
      end

      context 'and the user is not registered to any space associated with the isolation segment' do
        let(:other_space) { VCAP::CloudController::Space.make }

        before do
          allow_user_read_access(user, space: other_space)
          stub_readable_space_guids_for(user, other_space)
        end

        it 'returns a 403' do
          get :show, guid: isolation_segment.guid

          expect(response.status).to eq 403
        end
      end
    end
  end

  describe '#index' do
    let(:space) { VCAP::CloudController::Space.make }

    before do
      allow_user_read_access(user, space: space)
    end

    context 'when using query params' do
      context 'with invalid param format' do
        it 'returns a 400' do
          get :index, order_by: '^=%'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be 'created_at' or 'updated_at'")
        end
      end

      context 'with a parameter value outside the allowed values' do
        it 'returns a 400 and a list of allowed values' do
          get :index, order_by: 'name'

          expect(response.status).to eq 400
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be 'created_at' or 'updated_at'")
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
          stub_readable_org_guids_for(user, org1)
          org1.add_user(user)
          org2.add_user(user)
        end

        context 'and the org is associated with an isolation segment' do
          before do
            isolation_segment1.add_organization(org1)
            isolation_segment2.add_organization(org1)
          end

          it 'allows the user to see the isolation segment' do
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

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
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
          expect(parsed_body['links']['self']['href']).to eq("/v3/isolation_segments/#{isolation_segment_model.guid}")
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
      end

      context 'when the isolation segment does not exist' do
        it 'returns a 404 not found' do
          delete :destroy, guid: 'nonexistent-guid'

          expect(response.status).to eq 404
        end
      end

      context 'when the isolation segment is still associated to spaces' do
        before do
          VCAP::CloudController::Space.make(isolation_segment_guid: isolation_segment_model1.guid)
        end

        it 'returns a 400' do
          delete :destroy, guid: isolation_segment_model1.guid

          expect(response.status).to eq 400
          expect(parsed_body['error_code']).to eq('CF-AssociationNotEmpty')
          expect(parsed_body['description']).to eq('Please delete the space associations for your isolation segment.')
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
      VCAP::CloudController::IsolationSegmentModel[guid: VCAP::CloudController::IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID]
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

      expect(response.status).to eq 405
      expect(VCAP::CloudController::IsolationSegmentModel[guid: shared_segment.guid].exists?).to be true
    end

    it 'cannot be updated via API' do
      put :update, guid: shared_segment.guid, body: req_body

      expect(response.status).to eq 405
      expect(shared_segment.name).to eq(original_name)
    end
  end
end
